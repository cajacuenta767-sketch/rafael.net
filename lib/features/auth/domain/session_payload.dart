import 'dart:convert';

/// Datos de sesión extraídos de la respuesta de un login.
///
/// La API todavía no documenta el cuerpo de respuesta de
/// `/api/ClienteAuth/verificar-otp`, `/api/ClienteAuth/google` ni
/// `/api/YonkeAuth/login`: en el OpenAPI publicado las tres operaciones
/// declaran solamente `200 OK`, sin `content` ni
/// `schema`. Lo único confirmado del contrato es el sobre `ApiResponseGlobal`
/// (`success`, `message`, `data`, `statusCode`, `errors`), que sí aparece
/// documentado en las tres operaciones que publican respuesta.
///
/// Por eso [SessionResponseParser] prueba los nombres de clave habituales en
/// lugar de fijar uno solo, y conserva en [availableKeys] las claves que
/// realmente llegaron. Cuando el backend publique el DTO de sesión, basta con
/// dejar la clave real en las listas de candidatas y borrar el resto.
class SessionPayload {
  const SessionPayload({
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.userId,
    this.yonkeGuidId,
    this.role,
    this.serverMessage,
    this.availableKeys = const <String>[],
  });

  final String? accessToken;
  final String? refreshToken;

  /// Momento de expiración en UTC. Sale de una clave explícita de la respuesta
  /// o, en su defecto, del claim `exp` del propio JWT.
  final DateTime? expiresAt;

  final String? userId;

  /// Identificador del yonke autenticado. Perfil, cobertura y registro de
  /// dispositivo lo necesitan: `YonkesCoberturas/guid/{yonkeGuidId}` y
  /// `RegistrarDispositivoDto.yonkeGuidId` no funcionan sin él.
  ///
  /// En una respuesta de cliente este campo puede quedar con el guid del
  /// usuario, porque `guidId` es una de las claves candidatas. Solo el flujo
  /// del yonke lo consume, así que es inocuo.
  final String? yonkeGuidId;

  final String? role;
  final String? serverMessage;

  /// Claves presentes en la respuesta, para diagnosticar un contrato que
  /// todavía no está documentado. Nunca contiene valores, solo nombres.
  final List<String> availableKeys;

  bool get hasAccessToken =>
      accessToken != null && accessToken!.trim().isNotEmpty;

  bool get isExpired {
    final moment = expiresAt;
    if (moment == null) return false;
    return !moment.isAfter(DateTime.now().toUtc());
  }

  bool get isUsable => hasAccessToken && !isExpired;

  /// Resumen legible de las claves recibidas, para el mensaje de error cuando
  /// no se encontró ningún token.
  String get keysSummary =>
      availableKeys.isEmpty ? 'ninguna' : availableKeys.join(', ');
}

/// Interpreta la respuesta de un login sin asumir un nombre de clave único.
abstract final class SessionResponseParser {
  static const _accessTokenKeys = <String>[
    'accesstoken',
    'token',
    'jwt',
    'jwttoken',
    'bearertoken',
    'authtoken',
    'tokenacceso',
    'tokendeacceso',
    // Última opción: en el login de Google `idToken` es lo que la app envía,
    // no lo que debería recibir. Si el servidor lo devuelve tal cual, esto lo
    // acepta pero conviene confirmarlo con el backend.
    'idtoken',
  ];

  static const _refreshTokenKeys = <String>[
    'refreshtoken',
    'tokenrefresh',
    'tokenrenovacion',
    'renewtoken',
  ];

  /// Absolutas y relativas juntas: el tipo del valor decide cómo se interpreta.
  static const _expiryKeys = <String>[
    'expiresat',
    'expiresin',
    'expiration',
    'expira',
    'expiraen',
    'expiracion',
    'fechaexpiracion',
    'fechavencimiento',
    'vencimiento',
    'validohasta',
    'duracion',
  ];

  static const _userIdKeys = <String>[
    'userid',
    'usuarioid',
    'idusuario',
    'clienteid',
    'sub',
  ];

  static const _yonkeIdKeys = <String>[
    'yonkeguidid',
    'yunkeguidid',
    'yonkeid',
    'yunkeid',
    'guidid',
  ];

  static const _roleKeys = <String>[
    'rol',
    'role',
    'tipousuario',
    'tipocuenta',
    'perfil',
  ];

  /// Objetos que suelen envolver la sesión dentro de la respuesta.
  static const _containerKeys = <String>[
    'data',
    'result',
    'resultado',
    'session',
    'sesion',
    'auth',
    'payload',
    'usuario',
    'user',
    'cliente',
    'yonke',
  ];

  static final RegExp _jwtShape = RegExp(
    r'^[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*$',
  );

  /// Punto de entrada. Acepta cualquier cosa que devuelva el cliente HTTP.
  static SessionPayload parse(Object? response) {
    if (looksLikeJwt(response)) {
      final token = (response as String).trim();
      return SessionPayload(
        accessToken: token,
        expiresAt: expiryFromClaims(token),
        userId: _subjectFromClaims(token),
        role: _roleFromClaims(token),
        yonkeGuidId: _yonkeIdFromClaims(token),
      );
    }

    if (response is String) {
      try {
        final decoded = json.decode(response);
        if (decoded is Map) {
          response = decoded;
        }
      } catch (_) {}
    }

    if (response is! Map) return const SessionPayload();

    final root = _asStringMap(response);
    if (root == null) return const SessionPayload();
    final keys = _describeKeys(root);
    final message = _pickString(root, const <String>['message', 'mensaje']);

    // `data` puede venir siendo el token pelado, sin objeto alrededor.
    final data = _pick(root, const <String>['data']);
    if (looksLikeJwt(data)) {
      final token = (data as String).trim();
      return SessionPayload(
        accessToken: token,
        expiresAt: expiryFromClaims(token),
        userId: _subjectFromClaims(token),
        role: _roleFromClaims(token),
        yonkeGuidId: _yonkeIdFromClaims(token),
        serverMessage: message,
        availableKeys: keys,
      );
    }

    final scopes = _scopes(root);

    String? token;
    for (final scope in scopes) {
      final candidate = _pickString(scope, _accessTokenKeys);
      if (candidate != null) {
        token = candidate;
        break;
      }
    }
    // Último recurso: buscar cualquier valor con forma de JWT en el árbol.
    token ??= _deepJwt(root);

    if (token == null) {
      return SessionPayload(serverMessage: message, availableKeys: keys);
    }

    return SessionPayload(
      accessToken: token,
      refreshToken: _firstString(scopes, _refreshTokenKeys),
      expiresAt: _expiry(scopes, token),
      userId: _firstString(scopes, _userIdKeys) ?? _subjectFromClaims(token),
      yonkeGuidId:
          _firstString(scopes, _yonkeIdKeys) ?? _yonkeIdFromClaims(token),
      role: _firstString(scopes, _roleKeys) ?? _roleFromClaims(token),
      serverMessage: message,
      availableKeys: keys,
    );
  }

  static bool looksLikeJwt(Object? value) =>
      value is String && _jwtShape.hasMatch(value.trim());

  /// Decodifica el cuerpo de un JWT. Devuelve `null` si no se puede leer.
  static Map<String, dynamic>? decodeJwtClaims(String token) {
    final parts = token.trim().split('.');
    if (parts.length < 2) return null;

    var segment = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (segment.length % 4 != 0) {
      segment = '$segment=';
    }

    try {
      final claims = json.decode(utf8.decode(base64.decode(segment)));
      return claims is Map<String, dynamic> ? claims : null;
    } catch (_) {
      return null;
    }
  }

  static DateTime? expiryFromClaims(String token) {
    final exp = decodeJwtClaims(token)?['exp'];
    if (exp is num && exp > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp.round() * 1000,
        isUtc: true,
      );
    }
    return null;
  }

  /// Identificador del usuario (`sub`, `nameid`, `NameIdentifier`) leído de
  /// los claims de [token]. `null` si el token no se puede decodificar.
  static String? subjectFromToken(String token) => _subjectFromClaims(token);

  // --- internos -------------------------------------------------------------

  /// Convierte un mapa de origen desconocido. Devuelve `null` si alguna clave
  /// no es texto, en vez de dejar escapar una excepción de tipo.
  static Map<String, dynamic>? _asStringMap(Map<Object?, Object?> source) {
    final converted = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is! String) return null;
      converted[key] = entry.value;
    }
    return converted;
  }

  static String _canonical(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[_\-\s.]'), '');

  static Map<String, Object?> _index(Map<String, dynamic> source) {
    final indexed = <String, Object?>{};
    for (final entry in source.entries) {
      indexed.putIfAbsent(_canonical(entry.key), () => entry.value);
    }
    return indexed;
  }

  static Object? _pick(Map<String, dynamic> source, List<String> candidates) {
    final indexed = _index(source);
    for (final candidate in candidates) {
      final value = indexed[candidate];
      if (value != null) return value;
    }
    return null;
  }

  static String? _pickString(
    Map<String, dynamic> source,
    List<String> candidates,
  ) {
    final value = _pick(source, candidates);
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return value.toString();
    return null;
  }

  static String? _firstString(
    List<Map<String, dynamic>> scopes,
    List<String> candidates,
  ) {
    for (final scope in scopes) {
      final value = _pickString(scope, candidates);
      if (value != null) return value;
    }
    return null;
  }

  static Object? _firstValue(
    List<Map<String, dynamic>> scopes,
    List<String> candidates,
  ) {
    for (final scope in scopes) {
      final value = _pick(scope, candidates);
      if (value != null) return value;
    }
    return null;
  }

  /// Ámbitos de búsqueda, del más probable al menos: contenedores directos,
  /// luego la raíz, luego un nivel más adentro.
  static List<Map<String, dynamic>> _scopes(Map<String, dynamic> root) {
    final nested = _nestedMaps(root);
    final scopes = <Map<String, dynamic>>[...nested, root];
    for (final map in nested) {
      scopes.addAll(_nestedMaps(map));
    }
    return scopes;
  }

  static List<Map<String, dynamic>> _nestedMaps(Map<String, dynamic> source) {
    final indexed = _index(source);
    final maps = <Map<String, dynamic>>[];
    for (final key in _containerKeys) {
      final value = indexed[key];
      if (value is Map) {
        final map = _asStringMap(value);
        if (map != null) maps.add(map);
      }
    }
    return maps;
  }

  static String? _deepJwt(Object? node, [int depth = 0]) {
    if (depth > 5) return null;
    if (node is String) return looksLikeJwt(node) ? node.trim() : null;
    if (node is Map) {
      for (final value in node.values) {
        final found = _deepJwt(value, depth + 1);
        if (found != null) return found;
      }
      return null;
    }
    if (node is List) {
      for (final value in node) {
        final found = _deepJwt(value, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static DateTime? _expiry(List<Map<String, dynamic>> scopes, String token) =>
      _expiryFromValue(_firstValue(scopes, _expiryKeys)) ??
      expiryFromClaims(token);

  static DateTime? _expiryFromValue(Object? raw) {
    if (raw is num) return _fromSecondsOrEpoch(raw.round());
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final asNumber = int.tryParse(trimmed);
      if (asNumber != null) return _fromSecondsOrEpoch(asNumber);
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  /// Un número grande es un epoch absoluto; uno pequeño, segundos de vida.
  /// El corte deja fuera cualquier `expiresIn` razonable (un año son 3.2e7).
  static DateTime? _fromSecondsOrEpoch(int value) {
    if (value <= 0) return null;
    if (value > 100000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    return DateTime.now().toUtc().add(Duration(seconds: value));
  }

  static String? _subjectFromClaims(String token) {
    final claims = decodeJwtClaims(token);
    if (claims == null) return null;
    const candidates = <String>[
      'sub',
      'nameid',
      'uid',
      'userId',
      // ClaimTypes.NameIdentifier de ASP.NET.
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
    ];
    for (final key in candidates) {
      final value = claims[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _roleFromClaims(String token) {
    final claims = decodeJwtClaims(token);
    if (claims == null) return null;
    const candidates = <String>[
      'role',
      'rol',
      // ClaimTypes.Role de ASP.NET.
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
    ];
    for (final key in candidates) {
      final value = claims[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      }
    }
    return null;
  }

  static String? _yonkeIdFromClaims(String token) {
    final claims = decodeJwtClaims(token);
    if (claims == null) return null;
    const candidates = <String>[
      'yonkeguidid',
      'yunkeguidid',
      'yonkeid',
      'yunkeid',
      'guidid',
    ];
    final indexed = _index(claims);
    for (final key in candidates) {
      final value = indexed[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static List<String> _describeKeys(Map<String, dynamic> root) {
    final described = <String>[...root.keys];
    final data = _pick(root, const <String>['data']);
    if (data is Map) {
      for (final key in data.keys) {
        described.add('data.$key');
      }
    }
    return described;
  }
}
