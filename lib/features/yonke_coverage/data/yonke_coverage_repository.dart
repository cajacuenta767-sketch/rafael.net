import '../../catalogs/data/catalogs_api.dart';
import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_coverage.dart';
import '../../../core/network/paged_response.dart';

abstract interface class YonkeCoverageRepository {
  Future<YonkeCoverageSnapshot> load({required String? yonkeId});

  Future<void> save({required String yonkeId, required Set<int> cityIds});
}

/// Cobertura sobre `YonkesCoberturas/guid/{yonkeGuidId}` y `PUT
/// /api/YonkesCoberturas`. Requiere el guid del yonke autenticado que entrega
/// el login; sin él no se consulta ni modifica la cobertura de otro negocio.
class ApiYonkeCoverageRepository implements YonkeCoverageRepository {
  const ApiYonkeCoverageRepository(this._catalogsApi, this._yonkesApi);

  final CatalogsApi _catalogsApi;
  final YonkesApi _yonkesApi;

  @override
  Future<YonkeCoverageSnapshot> load({required String? yonkeId}) async {
    if (yonkeId == null || yonkeId.isEmpty) {
      throw const YonkeIdentityContractPendingException();
    }
    final cities = await _loadCities();
    final coverage = await _yonkesApi.getCoverage(yonkeId);
    return YonkeCoverageSnapshot(
      cities: cities,
      selectedCityIds: coverageCityIdsFromResponse(coverage),
    );
  }

  @override
  Future<void> save({required String yonkeId, required Set<int> cityIds}) =>
      _yonkesApi.updateCoverage(
        yonkeId: yonkeId,
        cityIds: cityIds.toList(growable: false),
      );

  Future<List<CoverageCity>> _loadCities() async {
    final states = _records(await _catalogsApi.getStates());
    final groups = await Future.wait(
      states.whereType<Map>().map((state) async {
        final stateId = state['id'];
        if (stateId is! int) return const <CoverageCity>[];
        final stateName = state['entidad']?.toString() ?? 'Estado';
        final cities = _records(await _catalogsApi.getCitiesByState(stateId));
        return coverageCitiesFromRecords(cities, stateName: stateName);
      }),
    );
    return groups.expand((cities) => cities).toList(growable: false);
  }
}

/// Registros `Ciudades`: `id`, `ciudad` y, si viene incluida, la entidad
/// anidada en `entidades.entidad`.
List<CoverageCity> coverageCitiesFromRecords(
  List<dynamic> records, {
  required String stateName,
}) => records
    .whereType<Map>()
    .map((city) {
      final id = city['id'];
      final name = city['ciudad']?.toString().trim();
      if (id is! int || name == null || name.isEmpty) return null;
      final state = city['entidades'];
      final nestedState = state is Map ? state['entidad']?.toString() : null;
      return CoverageCity(
        id: id,
        name: name,
        state: nestedState == null || nestedState.isEmpty
            ? stateName
            : nestedState,
      );
    })
    .whereType<CoverageCity>()
    .toList(growable: false);

/// Registros `YonkesCoberturas`: solo las coberturas con `activo` verdadero
/// (o sin el campo) cuentan como seleccionadas. Acepta la estructura anidada
/// `yunkeHeader.yunkeCoberturas` de la API real de Azure y listas directas.
Set<int> coverageCityIdsFromResponse(dynamic response) =>
    _coverageRecords(response)
        .whereType<Map>()
        .where((item) => item['activo'] != false)
        .map((item) => item['ciudadId'])
        .whereType<int>()
        .toSet();

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

List<dynamic> _records(dynamic response) => pagedRecords(response);
