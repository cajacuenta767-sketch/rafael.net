import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';
import 'requests_api.dart';

abstract interface class RequestSubmissionRepository {
  Future<RequestSubmissionResult> submit(RequestDraft draft);
}

/// Crea la solicitud (incluyendo la ciudad), adjunta fotos y la envía a los
/// yonkes con cobertura. Cada paso que falla se informa tal cual: nunca se
/// simula una solicitud creada.
class ApiRequestSubmissionRepository implements RequestSubmissionRepository {
  const ApiRequestSubmissionRepository(this._requestsApi, [this._dashboardApi]);

  final RequestsApi _requestsApi;
  final DashboardApi? _dashboardApi;

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) async {
    final brandId = draft.brandId;
    final modelId = draft.modelId;
    final year = draft.year;
    final cityId = draft.cityId;
    if (brandId == null || modelId == null || year == null || cityId == null) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.create,
      );
    }

    // El usuario lo toma el servidor del JWT; no se envía `usuarioId`.
    final dynamic response;
    try {
      response = await _requestsApi.create(
        brandId: brandId,
        modelId: modelId,
        year: year,
        part: draft.part,
        description: draft.description,
        cityIds: [cityId],
      );
    } on ApiException catch (error) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.create,
        customMessage: error.message,
      );
    }

    final returnedId = _requestIdFromResponse(response);
    if (returnedId == null) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.requestId,
      );
    }
    final requestId = await _confirmRequestId(returnedId, draft);

    if (draft.photos.isNotEmpty) {
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
          customMessage:
              'La solicitud fue creada, pero no se pudieron adjuntar las '
              'fotografías: ${error.message}',
        );
      }
    }

    try {
      await _requestsApi.sendToCoveredYonkes(requestId);
    } on ApiException catch (error) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
        customMessage:
            'La solicitud fue creada, pero no se pudo enviar a los yonkes: '
            '${error.message}',
      );
    }

    return RequestSubmissionResult(requestId: requestId);
  }

  /// `POST /api/Solicitudes` del API publicado devuelve el GuidId de un objeto
  /// distinto al que guarda (ver docs/BACKEND_ISSUES.md). La solicitud más
  /// reciente del cliente es la que se acaba de crear; si coincide con el
  /// borrador se usa su GuidId real. Si el dashboard no responde se conserva
  /// el identificador devuelto.
  Future<String> _confirmRequestId(
    String returnedId,
    RequestDraft draft,
  ) async {
    final dashboard = _dashboardApi;
    if (dashboard == null) return returnedId;
    try {
      final response = await dashboard.getRecentRequest();
      final recent = response is Map ? response['data'] ?? response : null;
      if (recent is! Map) return returnedId;
      final recentId = recent['guidId']?.toString().trim();
      if (recentId == null || recentId.isEmpty) return returnedId;
      if (recentId.toLowerCase() == returnedId.toLowerCase()) return returnedId;
      return matchesDraft(recent, draft) ? recentId : returnedId;
    } on ApiException {
      return returnedId;
    }
  }
}

/// Compara la solicitud más reciente del servidor con el borrador enviado.
bool matchesDraft(Map<dynamic, dynamic> recent, RequestDraft draft) {
  String norm(Object? value) => value?.toString().trim().toLowerCase() ?? '';
  final year = recent['año'] ?? recent['anio'] ?? recent['ano'];
  return norm(recent['piezaBuscada']) == norm(draft.part) &&
      recent['marcaId']?.toString() == draft.brandId?.toString() &&
      recent['modeloId']?.toString() == draft.modelId?.toString() &&
      year?.toString() == draft.year?.toString();
}

String? _requestIdFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;
  for (final key in const ['guidId', 'solicitudGuidId', 'requestId', 'id']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
