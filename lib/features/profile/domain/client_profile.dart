enum ClientProfileAvailability { available, unavailable }

class ClientProfile {
  const ClientProfile({this.id, this.name, this.email, this.phone, this.city});

  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? city;

  bool get hasConfirmedData =>
      _hasValue(name) ||
      _hasValue(email) ||
      _hasValue(phone) ||
      _hasValue(city);

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;
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
