import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/token_store.dart';
import '../../auth/domain/session_payload.dart';
import '../domain/client_profile.dart';

abstract interface class ClientProfileRepository {
  Future<ClientProfileSnapshot> load();
  Future<void> saveProfile(ClientProfile profile);
  Future<List<ClientAddress>> loadAddresses();
  Future<void> saveAddresses(List<ClientAddress> addresses);
  Future<bool> readNotificationsEnabled();
  Future<void> writeNotificationsEnabled(bool enabled);
}

/// Perfil limitado a información confirmada localmente.
///
/// El OpenAPI no publica una operación para consultar o actualizar el perfil
/// del cliente, así que no se inventan datos ni se simula una respuesta.
class LocalClientProfileRepository implements ClientProfileRepository {
  LocalClientProfileRepository({
    required this.tokenStore,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final TokenStore tokenStore;
  final FlutterSecureStorage _storage;

  static const _profileKey = 'client.profile';
  static const _addressesKey = 'client.addresses';
  static const _notificationsKey = 'client.notifications';

  @override
  Future<ClientProfileSnapshot> load() async {
    final token = await tokenStore.readAccessToken();
    final claims = token == null
        ? null
        : SessionResponseParser.decodeJwtClaims(token);
    final stored = await _readMap(_profileKey);
    final profile = ClientProfile(
      id: _first(stored?['id'], claims?['sub'], claims?['nameid']),
      name: _first(
        stored?['name'],
        claims?['name'],
        claims?['given_name'],
        'Cliente Refanet',
      ),
      email: _first(stored?['email'], claims?['email']),
      phone: _first(stored?['phone'], claims?['phone_number']),
      city: _first(stored?['city'], claims?['city']),
    );
    return ClientProfileSnapshot(
      availability: profile.hasConfirmedData
          ? ClientProfileAvailability.available
          : ClientProfileAvailability.unavailable,
      profile: profile,
    );
  }

  @override
  Future<void> saveProfile(ClientProfile profile) => _storage.write(
    key: _profileKey,
    value: jsonEncode({
      'id': profile.id,
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'city': profile.city,
    }),
  );

  @override
  Future<List<ClientAddress>> loadAddresses() async {
    final raw = await _storage.read(key: _addressesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ClientAddress.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.street.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveAddresses(List<ClientAddress> addresses) => _storage.write(
    key: _addressesKey,
    value: jsonEncode(addresses.map((item) => item.toJson()).toList()),
  );

  @override
  Future<bool> readNotificationsEnabled() async =>
      await _storage.read(key: _notificationsKey) != 'false';

  @override
  Future<void> writeNotificationsEnabled(bool enabled) =>
      _storage.write(key: _notificationsKey, value: enabled.toString());

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static String? _first(Object? a, [Object? b, Object? c, Object? d]) {
    for (final value in [a, b, c, d]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
