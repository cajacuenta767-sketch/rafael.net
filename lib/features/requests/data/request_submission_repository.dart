import '../../../core/network/api_file.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';
import 'requests_api.dart';

abstract interface class RequestSubmissionRepository {
  Future<RequestSubmissionResult> submit(RequestDraft draft);
}

/// Crea la solicitud (incluyendo la ciudad), adjunta fotos y la envía a los
/// yonkes con cobertura. No continúa si la API no confirma el guid creado.
class ApiRequestSubmissionRepository implements RequestSubmissionRepository {
  const ApiRequestSubmissionRepository(this._requestsApi);

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

    dynamic response;
    try {
      response = await _requestsApi.create(
        brandId: brandId,
        modelId: modelId,
        year: year,
        part: draft.part,
        description: draft.description,
        cityIds: [cityId],
      );
    } catch (_) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.create,
      );
    }

    final requestId = _requestIdFromResponse(response);
    if (requestId == null) {
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
      } catch (_) {
        throw RequestSubmissionException(
          stage: RequestSubmissionStage.images,
          requestId: requestId,
        );
      }
    }

    try {
      await _requestsApi.sendToCoveredYonkes(requestId);
    } catch (_) {
      throw RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: requestId,
      );
    }

    return RequestSubmissionResult(requestId: requestId, isDemo: false);
  }
}

class DemoRequestSubmissionRepository implements RequestSubmissionRepository {
  const DemoRequestSubmissionRepository();

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const RequestSubmissionResult(
      requestId: 'demo-request-created',
      isDemo: true,
    );
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
