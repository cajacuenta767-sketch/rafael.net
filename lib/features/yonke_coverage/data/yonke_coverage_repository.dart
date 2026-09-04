import '../../catalogs/data/catalogs_api.dart';
import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_coverage.dart';

abstract interface class YonkeCoverageRepository {
  Future<YonkeCoverageSnapshot> load({required String? yonkeId});

  Future<void> save({required String yonkeId, required Set<int> cityIds});
}

/// Las llamadas reales se mantienen listas para cuando YonkeAuth entregue el
/// guid del yonke autenticado. No se adivina ese valor ni se actualiza el
/// perfil de otro negocio.
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
      selectedCityIds: _coverageCityIds(coverage),
      isDemo: false,
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
        return cities
            .whereType<Map>()
            .map((city) {
              return CoverageCity(
                id: city['id'] as int,
                name: city['ciudad']?.toString() ?? 'Ciudad',
                // El backend actual expone "entidade" en esta respuesta.
                state: city['entidade']?.toString() ?? stateName,
              );
            })
            .toList(growable: false);
      }),
    );
    return groups.expand((cities) => cities).toList(growable: false);
  }
}

class DemoYonkeCoverageRepository implements YonkeCoverageRepository {
  const DemoYonkeCoverageRepository();

  @override
  Future<YonkeCoverageSnapshot> load({required String? yonkeId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const YonkeCoverageSnapshot(
      cities: [
        CoverageCity(id: 1, name: 'Nogales', state: 'Sonora'),
        CoverageCity(id: 2, name: 'Hermosillo', state: 'Sonora'),
        CoverageCity(id: 3, name: 'Agua Prieta', state: 'Sonora'),
        CoverageCity(id: 4, name: 'San Luis Río Colorado', state: 'Sonora'),
      ],
      selectedCityIds: {1, 2},
      isDemo: true,
    );
  }

  @override
  Future<void> save({required String yonkeId, required Set<int> cityIds}) =>
      Future<void>.delayed(const Duration(milliseconds: 180));
}

List<dynamic> _records(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is List) return data;
  if (data is Map) {
    final items = data['items'] ?? data['registros'];
    if (items is List) return items;
  }
  return const [];
}

Set<int> _coverageCityIds(dynamic response) {
  final records = _records(response);
  return records
      .whereType<Map>()
      .map((item) => item['ciudadId'])
      .whereType<int>()
      .toSet();
}
