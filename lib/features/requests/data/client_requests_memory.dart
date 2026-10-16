import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/domain/session_payload.dart';
import '../domain/client_request.dart';

class ClientRequestsMemory {
  ClientRequestsMemory({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _keyForEmail(String email) =>
      'client.requests.email.${email.trim().toLowerCase()}';

  Future<String?> _resolveEmail(String? email) async {
    final clean = email?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty) return clean;
    final last = await _storage.read(key: 'client.last_email');
    if (last != null && last.trim().isNotEmpty) return last.trim().toLowerCase();
    final token = await _storage.read(key: 'auth.access_token');
    if (token != null && token.isNotEmpty) {
      final claims = SessionResponseParser.decodeJwtClaims(token);
      final claimEmail = claims?['email']?.toString() ??
          claims?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
              ?.toString();
      if (claimEmail != null && claimEmail.trim().isNotEmpty) {
        return claimEmail.trim().toLowerCase();
      }
      final sub = claims?['sub']?.toString() ?? claims?['nameid']?.toString();
      if (sub != null && sub.trim().isNotEmpty) {
        return sub.trim().toLowerCase();
      }
    }
    return null;
  }

  Future<List<ClientRequestSummary>> loadRequests(String? email) async {
    final targetEmail = await _resolveEmail(email);
    if (targetEmail == null || targetEmail.isEmpty) return const [];
    final raw = await _storage.read(key: _keyForEmail(targetEmail));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) =>
              ClientRequestSummary.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveRequests(
    String? email,
    List<ClientRequestSummary> newOrUpdated,
  ) async {
    final targetEmail = await _resolveEmail(email);
    if (targetEmail == null || targetEmail.isEmpty) return;

    final existing = await loadRequests(targetEmail);
    final map = <String, ClientRequestSummary>{};

    // Primero conservamos todas las solicitudes antiguas guardadas
    for (final req in existing) {
      if (req.id.isNotEmpty) map[req.id] = req;
    }
    // Sobrescribimos o agregamos con la información más reciente de la API
    for (final req in newOrUpdated) {
      if (req.id.isNotEmpty) {
        final previous = map[req.id];
        // Conservar imagen previa si la nueva no trae
        if ((req.imageUrl == null || req.imageUrl!.isEmpty) &&
            previous?.imageUrl != null &&
            previous!.imageUrl!.isNotEmpty) {
          map[req.id] = req.copyWith(imageUrl: previous.imageUrl);
        } else {
          map[req.id] = req;
        }
      }
    }

    final combined = map.values.toList()
      ..sort((a, b) {
        final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

    await _storage.write(
      key: _keyForEmail(targetEmail),
      value: jsonEncode(combined.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addSingleRequest(
    String? email,
    ClientRequestSummary request,
  ) async {
    final targetEmail = await _resolveEmail(email);
    if (targetEmail == null || targetEmail.isEmpty) return;
    await saveRequests(targetEmail, [request]);
  }

  Future<void> markRequestCancelled(String? email, String requestId) async {
    final targetEmail = await _resolveEmail(email);
    if (targetEmail == null || targetEmail.isEmpty) return;
    final current = await loadRequests(targetEmail);
    final updated = current.map((r) {
      if (r.id == requestId) {
        return r.copyWith(status: 'Cancelada', closed: true);
      }
      return r;
    }).toList();
    await saveRequests(targetEmail, updated);
  }
}
