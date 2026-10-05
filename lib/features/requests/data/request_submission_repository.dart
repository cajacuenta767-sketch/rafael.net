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
  const ApiRequestSubmissionRepository(this._requestsApi, [DashboardApi? _]);

  final RequestsApi _requestsApi;

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
      final effectivePart =
          draft.partSide != null && draft.partSide!.trim().isNotEmpty
          ? '${draft.part.trim()} (${draft.partSide!.trim()})'
          : draft.part.trim();
      response = await _requestsApi.create(
        brandId: brandId,
        modelId: modelId,
        year: year,
        part: effectivePart,
        engine: draft.engine,
        transmission: draft.transmission,
        partNumber: draft.partNumber,
        description: draft.description,
        cityIds: [cityId],
      );
    } on ApiException catch (error) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.create,
        customMessage: error.message,
      );
    }

    final requestId = _requestIdFromResponse(response);
    if (requestId == null || requestId.isEmpty) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.requestId,
      );
    }

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
