enum ClientProfileAvailability { available, unavailable }

class ClientProfile {
  const ClientProfile({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.city,
    this.stateId,
    this.stateName,
    this.cityId,
    this.cityName,
    this.photoPath,
    this.photoUrl,
  });

  final String? id;
  final String? name;
  final String? email;
  final String? phone;

  /// Ciudad para mostrar ("Ciudad, Estado"). Los perfiles guardados antes del
  /// registro solo tienen este texto.
  final String? city;
  final int? stateId;
  final String? stateName;
  final int? cityId;
  final String? cityName;

  /// Foto elegida por el cliente, guardada en el dispositivo.
  final String? photoPath;

  /// Foto de la cuenta de Google.
  final String? photoUrl;

  bool get hasConfirmedData =>
      _hasValue(name) ||
      _hasValue(email) ||
      _hasValue(phone) ||
      _hasValue(city);

  /// Datos obligatorios del registro: nombre, teléfono, correo, estado y
  /// ciudad. La foto es opcional.
  bool get isComplete =>
      _hasValue(name) &&
      _hasValue(phone) &&
      _hasValue(email) &&
      stateId != null &&
      cityId != null;

  String? get displayCity {
    if (_hasValue(cityName)) {
      return _hasValue(stateName) ? '$cityName, $stateName' : cityName;
    }
    return city;
  }

  ClientProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? stateId,
    String? stateName,
    int? cityId,
    String? cityName,
    String? photoPath,
    String? photoUrl,
    bool clearPhotoPath = false,
  }) => ClientProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    city: city,
    stateId: stateId ?? this.stateId,
    stateName: stateName ?? this.stateName,
    cityId: cityId ?? this.cityId,
    cityName: cityName ?? this.cityName,
    photoPath: clearPhotoPath ? null : photoPath ?? this.photoPath,
    photoUrl: photoUrl ?? this.photoUrl,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'city': displayCity,
    'stateId': stateId,
    'stateName': stateName,
    'cityId': cityId,
    'cityName': cityName,
    'photoPath': photoPath,
    'photoUrl': photoUrl,
  };

  factory ClientProfile.fromJson(Map<String, dynamic> json) => ClientProfile(
    id: _string(json['id']),
    name: _string(json['name']),
    email: _string(json['email']),
    phone: _string(json['phone']),
    city: _string(json['city']),
    stateId: _int(json['stateId']),
    stateName: _string(json['stateName']),
    cityId: _int(json['cityId']),
    cityName: _string(json['cityName']),
    photoPath: _string(json['photoPath']),
    photoUrl: _string(json['photoUrl']),
  );

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}');
}

/// Lo que entregó el login (nombre y correo de Google, teléfono verificado
/// por OTP, foto de Google) para prellenar el registro.
class ClientLoginHints {
  const ClientLoginHints({this.name, this.email, this.phone, this.photoUrl});

  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;

  Map<String, Object?> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'photoUrl': photoUrl,
  };

  factory ClientLoginHints.fromJson(Map<String, dynamic> json) =>
      ClientLoginHints(
        name: json['name']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        photoUrl: json['photoUrl']?.toString(),
      );
}

class ClientAddress {
  const ClientAddress({
    required this.label,
    required this.street,
    required this.city,
    this.postalCode,
  });

  final String label;
  final String street;
  final String city;
  final String? postalCode;

  Map<String, Object?> toJson() => {
    'label': label,
    'street': street,
    'city': city,
    'postalCode': postalCode,
  };

  factory ClientAddress.fromJson(Map<String, dynamic> json) => ClientAddress(
    label: json['label']?.toString() ?? 'Dirección',
    street: json['street']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    postalCode: json['postalCode']?.toString(),
  );
}

class ClientProfileSnapshot {
  const ClientProfileSnapshot({
    required this.availability,
    this.profile = const ClientProfile(),
  });

  final ClientProfileAvailability availability;
  final ClientProfile profile;
}
