/// Estados y ciudades del catálogo `Utilerias` (`entidades` y
/// `entidad/{id}/ciudades`), compartidos por la ciudad de la solicitud y el
/// perfil del cliente.
library;

class StateOption {
  const StateOption({required this.id, required this.name});

  final int id;
  final String name;
}

class CityOption {
  const CityOption({
    required this.id,
    required this.name,
    required this.stateName,
  });

  final int id;
  final String name;
  final String stateName;

  String get fullName => stateName.isEmpty ? name : '$name, $stateName';
}

List<StateOption> statesFromResponse(dynamic response) => _records(response)
    .map(
      (record) => StateOption(
        id: _integer(record['id']) ?? -1,
        name: _text(record['entidad']) ?? '',
      ),
    )
    .where((state) => state.id > 0 && state.name.isNotEmpty)
    .toList(growable: false);

/// Registros `Ciudades`: `id`, `ciudad` y, cuando la API la incluye, la
/// entidad anidada en `entidades.entidad`; si no viene, se usa el nombre del
/// estado seleccionado.
List<CityOption> citiesFromResponse(
  dynamic response, {
  String? fallbackStateName,
}) => _records(response)
    .map(
      (record) => CityOption(
        id: _integer(record['id']) ?? -1,
        name: _text(record['ciudad']) ?? '',
        stateName: _nestedStateName(record) ?? fallbackStateName ?? '',
      ),
    )
    .where((city) => city.id > 0 && city.name.isNotEmpty)
    .toList(growable: false);

String? _nestedStateName(Map<dynamic, dynamic> record) {
  final state = record['entidades'];
  return state is Map ? _text(state['entidad']) : null;
}

List<Map<dynamic, dynamic>> _records(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  return data is List
      ? data.whereType<Map>().toList(growable: false)
      : const [];
}

int? _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value');

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
