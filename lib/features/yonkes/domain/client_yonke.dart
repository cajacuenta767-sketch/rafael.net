class ClientYonke {
  const ClientYonke({
    required this.id,
    required this.name,
    required this.ratingAverage,
    required this.ratingCount,
    this.cityId,
    this.city,
    this.state,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
  });

  final String id;
  final String name;
  final int? cityId;
  final String? city;
  final String? state;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;
  final double ratingAverage;
  final int ratingCount;

  String get location => [
    city,
    state,
  ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

  ClientYonke withRating({required double average, required int count}) =>
      ClientYonke(
        id: id,
        name: name,
        cityId: cityId,
        city: city,
        state: state,
        logoUrl: logoUrl,
        phone: phone,
        email: email,
        address: address,
        ratingAverage: average,
        ratingCount: count,
      );
}

class ClientYonkePage {
  const ClientYonkePage({
    required this.items,
    required this.page,
    required this.pageCount,
  });

  final List<ClientYonke> items;
  final int page;
  final int pageCount;

  bool get hasMore => page < pageCount;
}

class ClientYonkeCity {
  const ClientYonkeCity({
    required this.id,
    required this.name,
    required this.state,
  });

  final int id;
  final String name;
  final String state;

  String get label => '$name, $state';
}

class ClientYonkeDetail {
  const ClientYonkeDetail({
    required this.yonke,
    required this.ratingComments,
    required this.coverage,
  });

  final ClientYonke yonke;
  final List<String> ratingComments;
  final List<String> coverage;
}

ClientYonkePage clientYonkePageFromResponse(dynamic response) {
  final root = response is Map ? response['data'] ?? response : response;
  final records = switch (root) {
    List() => root,
    Map() when root['data'] is List => root['data'] as List,
    Map() when root['items'] is List => root['items'] as List,
    Map() when root['registros'] is List => root['registros'] as List,
    _ => const <dynamic>[],
  };
  final meta = root is Map && root['meta'] is Map ? root['meta'] as Map : null;
  final items = records
      .whereType<Map>()
      .map(clientYonkeFromJson)
      .whereType<ClientYonke>()
      .toList(growable: false);
  return ClientYonkePage(
    items: items,
    page: _integer(meta?['page']) ?? 1,
    pageCount: _integer(meta?['pageCount']) ?? 1,
  );
}

ClientYonke? clientYonkeFromResponse(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is Map ? clientYonkeFromJson(data) : null;
}

ClientYonke? clientYonkeFromJson(Map<dynamic, dynamic> json) {
  final id = _text(json['guidId']) ?? _text(json['yonkeGuidId']);
  final name = _text(json['nombre']) ?? _text(json['yonkeNombre']);
  if (id == null || name == null) return null;
  final cityRecord = json['ciudades'];
  final city = cityRecord is Map
      ? _text(cityRecord['ciudad'])
      : _text(json['ciudad']);
  final stateRecord = cityRecord is Map ? cityRecord['entidades'] : null;
  final state = stateRecord is Map
      ? _text(stateRecord['entidad'])
      : _text(json['entidad']) ?? _text(json['estado']);
  final ratings = json['yonkesCalificaciones'] is List
      ? (json['yonkesCalificaciones'] as List)
            .whereType<Map>()
            .where((item) => item['activa'] != false)
            .map((item) => _number(item['calificacion']))
            .whereType<double>()
            .where((value) => value >= 1 && value <= 5)
            .toList()
      : const <double>[];
  final average =
      _number(json['promedioCalificacion']) ??
      _number(json['calificacionPromedio']) ??
      _number(json['promedio']) ??
      (ratings.isEmpty
          ? 0
          : ratings.reduce((first, second) => first + second) / ratings.length);
  final count =
      _integer(json['totalCalificaciones']) ??
      _integer(json['numeroCalificaciones']) ??
      ratings.length;
  final logo = _text(json['logoUrl']);
  return ClientYonke(
    id: id,
    name: name,
    cityId: _integer(json['ciudadId']),
    city: city,
    state: state,
    logoUrl: _safeImage(logo) ? logo : null,
    phone: _text(json['telefono']),
    email: _text(json['correo']),
    address: _text(json['direccion']),
    ratingAverage: average,
    ratingCount: count,
  );
}

List<String> clientYonkeCoverageFromResponse(dynamic response) {
  final records = _coverageRecords(response);
  return records
      .whereType<Map>()
      .where((record) => record['activo'] != false)
      .map((record) {
        if (record['ciudad'] is String &&
            (record['ciudad'] as String).trim().isNotEmpty) {
          final cityName = (record['ciudad'] as String).trim();
          final stateName = _text(record['estado'] ?? record['entidad']);
          return stateName == null ? cityName : '$cityName, $stateName';
        }
        final city = record['ciudades'];
        if (city is Map) {
          final name = _text(city['ciudad']);
          final state = city['entidades'];
          final stateName = state is Map ? _text(state['entidad']) : null;
          if (name == null) return null;
          return stateName == null ? name : '$name, $stateName';
        }
        final fallback = _text(record['nombre'] ?? record['ciudadNombre']);
        return fallback;
      })
      .whereType<String>()
      .toList(growable: false);
}

List<dynamic> _coverageRecords(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is Map) {
    final header = data['yunkeHeader'] ?? data['yonkeHeader'];
    if (header is Map) {
      final coberturas =
          header['yunkeCoberturas'] ??
          header['yonkeCoberturas'] ??
          header['coberturas'];
      if (coberturas is List) return coberturas;
    }
    final direct =
        data['yunkeCoberturas'] ??
        data['yonkeCoberturas'] ??
        data['coberturas'];
    if (direct is List) return direct;
  }
  return _records(response);
}

List<ClientYonkeCity> clientYonkeCitiesFromRecords(
  List<dynamic> records, {
  required String state,
}) => records
    .whereType<Map>()
    .map((record) {
      final id = _integer(record['id']);
      final name = _text(record['ciudad']);
      return id == null || name == null
          ? null
          : ClientYonkeCity(id: id, name: name, state: state);
    })
    .whereType<ClientYonkeCity>()
    .toList(growable: false);

List<dynamic> clientYonkeRecords(dynamic response) => _records(response);

List<dynamic> _records(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is List) return data;
  if (data is Map) {
    final records = data['data'] ?? data['items'] ?? data['registros'];
    if (records is List) return records;
  }
  return const [];
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

bool _safeImage(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
