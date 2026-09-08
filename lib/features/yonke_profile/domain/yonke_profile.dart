enum YonkeProfileAvailability { available, identityPending }

/// Datos del yonke según el esquema `Yonkes` del OpenAPI.
class YonkeProfile {
  const YonkeProfile({
    required this.guidId,
    this.name,
    this.manager,
    this.phone,
    this.email,
    this.address,
    this.postalCode,
    this.cityId,
    this.city,
    this.logoUrl,
  });

  final String guidId;
  final String? name;
  final String? manager;
  final String? phone;
  final String? email;
  final String? address;
  final int? postalCode;
  final int? cityId;
  final String? city;
  final String? logoUrl;

  String get fullAddress => [
    address,
    postalCode == null ? null : 'C.P. $postalCode',
    city,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

class YonkeProfileSnapshot {
  const YonkeProfileSnapshot({required this.availability, this.profile});

  final YonkeProfileAvailability availability;
  final YonkeProfile? profile;
}

/// Interpreta `GET /api/Yonkes/{guidId}`: `guidId`, `nombre`, `responsable`,
/// `telefono`, `correo`, `direccion`, `cp`, `ciudadId`, `logoUrl` y, si viene
/// incluida, `ciudades.ciudad` con `ciudades.entidades.entidad`.
YonkeProfile? yonkeProfileFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is! Map) return null;
  final guidId = _text(data['guidId']);
  if (guidId == null) return null;
  final cityRecord = data['ciudades'];
  String? city;
  if (cityRecord is Map) {
    final name = _text(cityRecord['ciudad']);
    final state = cityRecord['entidades'];
    final stateName = state is Map ? _text(state['entidad']) : null;
    city = name == null
        ? null
        : stateName == null
        ? name
        : '$name, $stateName';
  }
  final logo = _text(data['logoUrl']);
  return YonkeProfile(
    guidId: guidId,
    name: _text(data['nombre']),
    manager: _text(data['responsable']),
    phone: _text(data['telefono']),
    email: _text(data['correo']),
    address: _text(data['direccion']),
    postalCode: (data['cp'] as num?)?.toInt(),
    cityId: (data['ciudadId'] as num?)?.toInt(),
    city: city,
    logoUrl:
        logo != null &&
            (logo.startsWith('https://') || logo.startsWith('asset://assets/'))
        ? logo
        : null,
  );
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
