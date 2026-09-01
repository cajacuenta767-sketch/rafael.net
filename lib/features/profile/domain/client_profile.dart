enum ClientProfileAvailability { available, unavailable, demo }

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

class ClientProfileSnapshot {
  const ClientProfileSnapshot({
    required this.availability,
    this.profile = const ClientProfile(),
  });

  final ClientProfileAvailability availability;
  final ClientProfile profile;
}
