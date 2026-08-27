import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_file.dart';

class QuotesApi {
  const QuotesApi(this._client);

  final ApiClient _client;

  Future<dynamic> create({
    required String requestYonkeId,
    required Map<String, dynamic> fields,
    List<ApiFile> images = const [],
  }) => _client.multipart(
    ApiEndpoints.quotes,
    method: 'POST',
    fields: fields,
    files: images,
    queryParameters: {'solicitudYonkeGuidId': requestYonkeId},
  );

  Future<dynamic> update({
    required String quoteId,
    required Map<String, dynamic> payload,
  }) => _client.put(ApiEndpoints.quote(quoteId), data: payload);

  Future<dynamic> getById(String quoteId) =>
      _client.get(ApiEndpoints.quote(quoteId));

  Future<dynamic> sendMessage({
    required String quoteId,
    required String message,
  }) => _client.post(
    ApiEndpoints.quoteMessages,
    data: {'solicitudCotizacionGuidId': quoteId, 'mensaje': message},
  );

  Future<dynamic> getConversation(String quoteId) =>
      _client.get(ApiEndpoints.quoteConversation(quoteId));

  Future<dynamic> markMessagesRead(String quoteId) =>
      _client.put(ApiEndpoints.markQuoteMessagesRead(quoteId));

  Future<dynamic> getUnreadCount(String quoteId) =>
      _client.get(ApiEndpoints.unreadQuoteMessages(quoteId));
}
