import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';
import '../domain/client_request.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';
import 'requests_api.dart';

abstract interface class RequestSubmissionRepository {
  Future<RequestSubmissionResult> submit(RequestDraft draft);

  /// Reanuda un envío cuya solicitud ya fue creada ([requestId]) pero falló
  /// al subir fotos o al enviarla a los yonkes. No vuelve a crear la solicitud.
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  });
}

/// Envío real de una solicitud, en el orden que exige la API:
///
/// 1. `POST /api/Solicitudes` con la ciudad en `ciudadesIds`. El usuario lo
///    identifica el token de la sesión; la app no envía ningún `usuarioId`.
/// 2. Comprueba que la ciudad quedó asociada (`SolicitudCiudades`) y, si el
///    servidor no la registró, la agrega. Sin ciudad ningún yonke la recibe.
/// 3. `POST /api/SolicitudesImagenes/{id}` con las fotografías, si las hay.
/// 4. `POST /api/SolicitudYonkes/{id}/enviar`, que asigna la solicitud a los
///    yonkes con cobertura. Si esta llamada falla, se informa: la solicitud
///    existe en el servidor pero nadie la recibió.
class ApiRequestSubmissionRepository implements RequestSubmissionRepository {
  const ApiRequestSubmissionRepository(this._requestsApi);

  final RequestsApi _requestsApi;

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) async {
    final brandId = draft.brandId;
    final modelId = draft.modelId;
    final year = draft.year;
    final cityId = draft.cityId;
    if (brandId == null ||
        modelId == null ||
        year == null ||
        cityId == null ||
        draft.part.trim().isEmpty) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.create,
        customMessage: 'Faltan datos de la solicitud: pieza, marca, modelo, año y ciudad son obligatorios.',
      );
    }

    // 1. Crear la solicitud.
    dynamic created;
    try {
      created = await _requestsApi.create(
        brandId: brandId,
        modelId: modelId,
        year: year,
        part: draft.part,
        description: draft.description,
        cityIds: draft.allCityIds,
      );
    } on ApiException catch (error) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.create,
        customMessage: error.message,
      );
    } catch (_) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.create,
      );
    }
    final createError = envelopeErrorMessage(created);
    if (createError != null) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.create,
        customMessage: createError,
      );
    }
    final requestId = requestIdFromCreateResponse(created);
    if (requestId == null) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.requestId,
      );
    }

    // 2. Asegurar las ciudades de cobertura.
    for (final id in draft.allCityIds) {
      await _ensureCity(requestId, id);
    }
    return _finish(draft, requestId, uploadImages: true);
  }

  @override
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  }) => _finish(
    draft,
    requestId,
    uploadImages: failedStage == RequestSubmissionStage.images,
  );

  /// Pasos 3 y 4: fotografías y envío a yonkes. [uploadImages] es falso al
  /// reanudar un envío cuyas fotos ya quedaron registradas.
  Future<RequestSubmissionResult> _finish(
    RequestDraft draft,
    String requestId, {
    required bool uploadImages,
  }) async {
    // 3. Fotografías.
    if (uploadImages && draft.photos.isNotEmpty) {
      try {
        await _requestsApi.addImages(
          requestId,
          draft.photos
              .map(
                (photo) => ApiFile(
                  fieldName: 'imagenes',
                  fileName: photo.file.name,
                  bytes: photo.bytes,
                ),
              )
              .toList(growable: false),
        );
      } on ApiException catch (error) {
        throw RequestSubmissionException(
          stage: RequestSubmissionStage.images,
          requestId: requestId,
          customMessage: error.message,
        );
      } catch (_) {
        throw RequestSubmissionException(
          stage: RequestSubmissionStage.images,
          requestId: requestId,
        );
      }
    }

    // 4. Enviar a los yonkes con cobertura.
    dynamic dispatched;
    try {
      dispatched = await _requestsApi.sendToCoveredYonkes(requestId);
    } on ApiException catch (error) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
        customMessage: error.message,
      );
    } catch (_) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
      );
    }
    final dispatchError = envelopeErrorMessage(dispatched);
    if (dispatchError != null) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
        customMessage: dispatchError,
      );
    }

    return RequestSubmissionResult(
      requestId: requestId,
      notifiedYonkes: notifiedYonkesFromResponse(dispatched),
      dispatchMessage: envelopeMessage(dispatched),
    );
  }

  /// `ciudadesIds` viaja en la creación, pero la asignación a yonkes depende
  /// de `SolicitudesCiudades`. Si el servidor no registró la ciudad, se agrega
  /// con `POST /api/SolicitudCiudades/{id}/ciudades`. Un fallo al consultar no
  /// detiene el envío: el resultado de `enviar` es la señal definitiva.
  Future<void> _ensureCity(String requestId, int cityId) async {
    List<int>? linked;
    try {
      linked = requestCityIdsFromResponse(
        await _requestsApi.getCities(requestId),
      );
    } catch (_) {
      linked = null;
    }
    if (linked == null || linked.contains(cityId)) return;
    try {
      await _requestsApi.addCities(requestId, [cityId]);
    } catch (_) {
      // Si el servidor rechaza la ciudad, `enviar` lo reflejará en su
      // respuesta (ningún yonke asignado) y la pantalla lo mostrará.
    }
  }
}

/// `data.guidId` (o variantes) de la respuesta de `POST /api/Solicitudes`.
/// También acepta el guid como texto plano en `data`.
String? requestIdFromCreateResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;
  for (final key in const ['guidId', 'solicitudGuidId', 'requestId', 'id']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  final nested = data['solicitud'] ?? data['solicitudHeader'];
  if (nested is Map) return requestIdFromCreateResponse(nested);
  return null;
}

/// Mensaje de error cuando el sobre `ApiResponseGlobal` llega con
/// `success: false` aunque el HTTP haya sido 200.
String? envelopeErrorMessage(dynamic response) {
  if (response is! Map || response['success'] != false) return null;
  return envelopeMessage(response) ??
      'El servidor rechazó la operación sin indicar el motivo.';
}

String? envelopeMessage(dynamic response) {
  if (response is! Map) return null;
  final message = response['message'] ?? response['mensaje'];
  final text = message?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// Interpreta la respuesta de `POST /api/SolicitudYonkes/{id}/enviar`.
/// Acepta un número, una lista de `SolicitudYonkes` o un objeto con un
/// contador; devuelve `null` si no reconoce la forma.
int? notifiedYonkesFromResponse(dynamic response) {
  final data = response is Map && response.containsKey('data')
      ? response['data']
      : response;
  if (data is num) return data.toInt();
  if (data is List) return data.length;
  if (data is String) {
    final parsed = int.tryParse(data.trim());
    if (parsed != null) return parsed;
    return _countFromText(data);
  }
  if (data is Map) {
    for (final key in const [
      'yonkesNotificados',
      'totalYonkes',
      'yonkesEnviados',
      'enviados',
      'enviadas',
      'total',
      'cantidad',
      'count',
      'totalEnviados',
      'asignados',
    ]) {
      final value = data[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    for (final key in const ['yonkes', 'solicitudYonkes', 'asignaciones']) {
      final value = data[key];
      if (value is List) return value.length;
    }
  }
  if (response is Map) {
    final message = envelopeMessage(response);
    if (message != null) return _countFromText(message);
  }
  return null;
}

/// «Solicitud enviada a 3 yonkes» → 3. Solo cuando el texto menciona yonkes.
int? _countFromText(String text) {
  final match = RegExp(r'(\d+)\s+yonke', caseSensitive: false).firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}
