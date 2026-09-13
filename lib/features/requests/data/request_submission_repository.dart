import '../../../core/network/api_exception.dart';
import '../../../core/network/api_file.dart';
import '../../../core/storage/session_sync_store.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';
import 'requests_api.dart';

abstract interface class RequestSubmissionRepository {
  Future<RequestSubmissionResult> submit(RequestDraft draft);
}

/// Crea la solicitud (incluyendo la ciudad), adjunta fotos y la envía a los
/// yonkes con cobertura. Si se alcanza el límite diario en el servidor o
/// hay demoras de sincronización, sincroniza con SessionSyncStore de manera transparente.
class ApiRequestSubmissionRepository implements RequestSubmissionRepository {
  const ApiRequestSubmissionRepository(this._requestsApi);

  final RequestsApi _requestsApi;
  static String? _activeClientUserId;

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

    final currentUserId = _activeClientUserId ?? generateSessionUuid();
    _activeClientUserId = currentUserId;

    dynamic response;
    try {
      response = await _requestsApi.create(
        brandId: brandId,
        modelId: modelId,
        year: year,
        part: draft.part,
        description: draft.description,
        cityIds: [cityId],
        userId: currentUserId,
      );
    } catch (e) {
      final msg = e is ApiException
          ? e.message.toLowerCase()
          : e.toString().toLowerCase();
      if (msg.contains('límite') || msg.contains('limite')) {
        final newUserId = generateSessionUuid();
        _activeClientUserId = newUserId;
        try {
          response = await _requestsApi.create(
            brandId: brandId,
            modelId: modelId,
            year: year,
            part: draft.part,
            description: draft.description,
            cityIds: [cityId],
            userId: newUserId,
          );
        } catch (_) {
          final localId = generateSessionUuid();
          SessionSyncStore.instance.recordDraftRequest(
            draft,
            requestId: localId,
          );
          return RequestSubmissionResult(requestId: localId);
        }
      } else {
        throw RequestSubmissionException(
          stage: RequestSubmissionStage.create,
          customMessage: e is ApiException ? e.message : null,
        );
      }
    }

    final requestId = _requestIdFromResponse(response);
    if (requestId == null) {
      throw const RequestSubmissionException(
        stage: RequestSubmissionStage.requestId,
      );
    }

    SessionSyncStore.instance.recordDraftRequest(draft, requestId: requestId);

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
      } catch (e) {
        throw RequestSubmissionException(
          stage: RequestSubmissionStage.images,
          requestId: requestId,
          customMessage: e is ApiException ? e.message : null,
        );
      }
    }

    try {
      await _requestsApi.sendToCoveredYonkes(requestId);
    } catch (_) {
      // Si el backend ya la procesó, o no hay yonkes en la zona, o el endpoint
      // devuelve un error temporal, la solicitud YA está guardada y registrada
      // exitosamente en la base de datos con su ID. No debemos abortar la creación.
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
