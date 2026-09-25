import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

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

  /// `true` cuando hay sesión y esta cuenta todavía no completó su perfil en
  /// este dispositivo.
  Future<bool> needsOnboarding();

  /// Perfil para el registro: lo ya guardado, o lo que entregó el login
  /// (nombre y correo de Google, teléfono verificado por OTP).
  Future<ClientProfile> draftForOnboarding();

  Future<void> saveLoginHints(ClientLoginHints hints);

  /// Guarda la foto elegida y devuelve su ruta local.
  Future<String> savePhoto(Uint8List bytes, {required String extension});

  Future<void> deletePhoto(String path);
}

/// Perfil guardado en el dispositivo, por cuenta (`sub` del JWT).
///
/// El API no publica una operación para consultar o actualizar el perfil del
/// cliente (ver docs/BACKEND_ISSUES.md). Cuando exista, basta con otra
/// implementación de [ClientProfileRepository].
class LocalClientProfileRepository implements ClientProfileRepository {
  LocalClientProfileRepository({
    required this.tokenStore,
    FlutterSecureStorage? storage,
    Future<Directory> Function()? photosDirectory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _photosDirectory = photosDirectory ?? _defaultPhotosDirectory;

  final TokenStore tokenStore;
  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _photosDirectory;

  /// Clave anterior, compartida por todas las cuentas del dispositivo.
  static const _legacyProfileKey = 'client.profile';
  static const _legacyAddressesKey = 'client.addresses';
  static const _notificationsKey = 'client.notifications';

  /// Nombre que el API asigna a los clientes creados por OTP.
  static const _defaultServerName = 'cliente refanet';

  static const _nameClaims = [
    'name',
    'given_name',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
    'unique_name',
  ];
  static const _emailClaims = [
    'email',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
  ];
  static const _phoneClaims = [
    'phone_number',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone',
  ];

  @override
  Future<ClientProfileSnapshot> load() async {
    final claims = await _claims();
    final stored = await _storedProfile(claims);
    final profile = ClientProfile(
      id: stored?.id ?? _subject(claims),
      name: _first([stored?.name, _realName(_claim(claims, _nameClaims))]),
      email: _first([stored?.email, _claim(claims, _emailClaims)]),
      phone: _first([stored?.phone, _claim(claims, _phoneClaims)]),
      city: stored?.displayCity,
      stateId: stored?.stateId,
      stateName: stored?.stateName,
      cityId: stored?.cityId,
      cityName: stored?.cityName,
      photoPath: stored?.photoPath,
      photoUrl: stored?.photoUrl,
    );
    return ClientProfileSnapshot(
      availability: profile.hasConfirmedData
          ? ClientProfileAvailability.available
          : ClientProfileAvailability.unavailable,
      profile: profile,
    );
  }

  @override
  Future<bool> needsOnboarding() async {
    try {
      final claims = await _claims();
      if (claims == null) return false;
      final stored = await _storedProfile(claims);
      return stored?.isComplete != true;
    } catch (_) {
      // Si el almacenamiento falla no se bloquea el acceso a la app.
      return false;
    }
  }

  @override
  Future<ClientProfile> draftForOnboarding() async {
    final claims = await _claims();
    final stored = await _storedProfile(claims);
    final hints = await _hints(claims);
    return ClientProfile(
      id: stored?.id ?? _subject(claims),
      name: _first([
        _realName(stored?.name),
        _realName(hints?.name),
        _realName(_claim(claims, _nameClaims)),
      ]),
      email: _first([
        stored?.email,
        hints?.email,
        _claim(claims, _emailClaims),
      ]),
      phone: _first([
        stored?.phone,
        hints?.phone,
        _claim(claims, _phoneClaims),
      ]),
      stateId: stored?.stateId,
      stateName: stored?.stateName,
      cityId: stored?.cityId,
      cityName: stored?.cityName,
      photoPath: stored?.photoPath,
      photoUrl: _first([stored?.photoUrl, hints?.photoUrl]),
    );
  }

  @override
  Future<void> saveLoginHints(ClientLoginHints hints) async {
    final subject = _subject(await _claims());
    if (subject == null) return;
    await _storage.write(
      key: 'client.loginHints.$subject',
      value: jsonEncode(hints.toJson()),
    );
  }

  @override
  Future<void> saveProfile(ClientProfile profile) async {
    final subject = _subject(await _claims());
    await _storage.write(
      key: subject == null ? _legacyProfileKey : _profileKey(subject),
      value: jsonEncode(profile.toJson()),
    );
  }

  @override
  Future<String> savePhoto(Uint8List bytes, {required String extension}) async {
    final subject = _subject(await _claims()) ?? 'cliente';
    final directory = await _photosDirectory();
    await directory.create(recursive: true);
    final clean = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final file = File(
      '${directory.path}/$subject-${DateTime.now().millisecondsSinceEpoch}.'
      '${clean.isEmpty ? 'jpg' : clean.toLowerCase()}',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  Future<List<ClientAddress>> loadAddresses() async {
    final subject = _subject(await _claims());
    final raw =
        await _storage.read(key: _addressesKey(subject)) ??
        await _storage.read(key: _legacyAddressesKey);
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
  Future<void> saveAddresses(List<ClientAddress> addresses) async {
    final subject = _subject(await _claims());
    await _storage.write(
      key: _addressesKey(subject),
      value: jsonEncode(addresses.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<bool> readNotificationsEnabled() async =>
      await _storage.read(key: _notificationsKey) != 'false';

  @override
  Future<void> writeNotificationsEnabled(bool enabled) =>
      _storage.write(key: _notificationsKey, value: enabled.toString());

  static String _profileKey(String subject) => 'client.profile.$subject';

  static String _addressesKey(String? subject) =>
      subject == null ? _legacyAddressesKey : 'client.addresses.$subject';

  Future<Map<String, dynamic>?> _claims() async {
    final token = await tokenStore.readAccessToken();
    if (token == null || token.isEmpty) return null;
    return SessionResponseParser.decodeJwtClaims(token);
  }

  static String? _subject(Map<String, dynamic>? claims) => _first([
    claims?['sub']?.toString(),
    claims?['nameid']?.toString(),
    claims?['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
        ?.toString(),
  ]);

  static String? _claim(Map<String, dynamic>? claims, List<String> keys) =>
      _first([for (final key in keys) claims?[key]?.toString()]);

  /// Perfil de la cuenta de la sesión. El perfil guardado con la clave
  /// anterior se adopta solo si pertenece a esta misma cuenta.
  Future<ClientProfile?> _storedProfile(Map<String, dynamic>? claims) async {
    final subject = _subject(claims);
    if (subject != null) {
      final own = await _readMap(_profileKey(subject));
      if (own != null) return ClientProfile.fromJson(own);
    }
    final legacy = await _readMap(_legacyProfileKey);
    if (legacy == null) return null;
    final profile = ClientProfile.fromJson(legacy);
    if (subject == null) return profile;
    if (profile.id != subject) return null;
    await _storage.write(
      key: _profileKey(subject),
      value: jsonEncode(profile.toJson()),
    );
    await _storage.delete(key: _legacyProfileKey);
    return profile;
  }

  Future<ClientLoginHints?> _hints(Map<String, dynamic>? claims) async {
    final subject = _subject(claims);
    if (subject == null) return null;
    final map = await _readMap('client.loginHints.$subject');
    return map == null ? null : ClientLoginHints.fromJson(map);
  }

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

  /// Descarta el nombre genérico del API y los "nombres" que en realidad son
  /// un teléfono (el login por OTP no entrega nombre).
  static String? _realName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.toLowerCase() == _defaultServerName) return null;
    if (RegExp(r'^[+\d\s()-]+$').hasMatch(text)) return null;
    return text;
  }

  static String? _first(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static Future<Directory> _defaultPhotosDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/perfil');
  }
}
