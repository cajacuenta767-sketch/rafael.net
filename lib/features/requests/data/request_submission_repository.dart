import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';
import '../domain/client_request.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';
import 'requests_api.dart';

/// Aviso cuando el servidor ya despachó la solicitud al crearla y el paso
/// `enviar` falló por su cuenta.
const autoDispatchNotice =
    'Tu solicitud quedó registrada y enviada a los yonkes con cobertura.';

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
        technicalDetail: technicalDetailOf(error),
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
        technicalDetail: 'HTTP 200 · ${_compact(created)}',
      );
    }
    final requestId = requestIdFromCreateResponse(created);
    if (requestId == null) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.requestId,
        customMessage:
            'La API aceptó la solicitud, pero no devolvió su guidId. Por '
            'seguridad no se adjuntaron fotos ni se envió a los yonkes. '
            'Datos recibidos: ${describeCreateResponse(created)}.',
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
          technicalDetail: technicalDetailOf(error),
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
      // El servidor real despacha la solicitud a los yonkes con cobertura en
      // el momento de crearla y `enviar` responde 500 sin cuerpo (comprobado
      // en Swagger, 13/09/2026). Si la solicitud existe, el envío ya ocurrió y
      // no se debe mostrar un error al cliente.
      if (_isServerFailure(error) && await _requestExists(requestId)) {
        return RequestSubmissionResult(
          requestId: requestId,
          dispatchMessage: autoDispatchNotice,
        );
      }
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
        customMessage: error.message,
        technicalDetail: technicalDetailOf(error),
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
        technicalDetail: 'HTTP 200 · ${_compact(dispatched)}',
      );
    }

    return RequestSubmissionResult(
      requestId: requestId,
      notifiedYonkes: notifiedYonkesFromResponse(dispatched),
      dispatchMessage: envelopeMessage(dispatched),
    );
  }

  bool _isServerFailure(ApiException error) =>
      error.statusCode != null && error.statusCode! >= 500;

  Future<bool> _requestExists(String requestId) async {
    try {
      final response = await _requestsApi.getById(requestId);
      return envelopeErrorMessage(response) == null;
    } catch (_) {
      return false;
    }
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
  if (data is String) return _asRequestId(data, strict: true);
  if (data is! Map) return null;
  // 1. Un GUID en cualquiera de las claves conocidas, incluida `id`.
  for (final key in _idKeys) {
    final guid = _asRequestId(data[key], strict: true);
    if (guid != null) return guid;
  }
  // 2. Un GUID en objetos anidados (`solicitud`, `solicitudHeader`, entidad).
  final nested = _findGuid(data, depth: 3);
  if (nested != null) return nested;
  // 3. Claves explícitas de guid con un texto no numérico. Nunca `id`, que
  //    suele ser el entero de base de datos y no sirve en las rutas.
  for (final key in _idKeys.where((k) => k != 'id')) {
    final loose = _asRequestId(data[key], strict: false);
    if (loose != null) return loose;
  }
  return null;
}

const _idKeys = ['guidId', 'solicitudGuidId', 'requestId', 'guid', 'id'];

final _guidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Las rutas `SolicitudCiudades`, `SolicitudesImagenes` y `SolicitudYonkes`
/// reciben el `guidId`; un `id` numérico produce "La solicitud no existe".
/// En modo estricto solo se acepta la forma GUID; en modo laxo, cualquier
/// texto que no sea un número.
String? _asRequestId(dynamic value, {required bool strict}) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  if (_guidPattern.hasMatch(text)) return text;
  if (strict) return null;
  return int.tryParse(text) == null ? text : null;
}

String? _findGuid(Map<dynamic, dynamic> map, {required int depth}) {
  if (depth < 0) return null;
  for (final entry in map.entries) {
    final key = entry.key.toString().toLowerCase();
    if (key.contains('guid') || key == 'id') {
      final guid = _asRequestId(entry.value, strict: true);
      if (guid != null) return guid;
    }
  }
  for (final value in map.values) {
    if (value is Map) {
      final guid = _findGuid(value, depth: depth - 1);
      if (guid != null) return guid;
    }
  }
  return null;
}

/// Código y cuerpo de una respuesta de error, recortados para mostrarlos.
String technicalDetailOf(ApiException error) {
  final code = error.statusCode == null
      ? 'sin código'
      : 'HTTP ${error.statusCode}';
  return '$code · ${_compact(error.details)}';
}

String _compact(dynamic body) {
  final text = body == null ? 'sin cuerpo' : body.toString().trim();
  return text.length <= 300 ? text : '${text.substring(0, 300)}…';
}

/// Claves recibidas en la respuesta de creación, para diagnóstico.
String describeCreateResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data == null) return 'sin datos';
  if (data is Map) return data.keys.map((k) => k.toString()).join(', ');
  return data.runtimeType.toString();
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
