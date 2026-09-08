import '../../catalogs/data/catalogs_api.dart';
import '../../ratings/data/yonke_reputation_repository.dart';
import '../domain/client_yonke.dart';
import 'yonkes_api.dart';

abstract interface class ClientYonkesRepository {
  Future<ClientYonkePage> getPage({
    required int page,
    required int pageSize,
    String? search,
    int? cityId,
  });

  Future<List<ClientYonkeCity>> getCities();

  Future<ClientYonkeDetail> getDetail(ClientYonke initial);
}

class ApiClientYonkesRepository implements ClientYonkesRepository {
  const ApiClientYonkesRepository(this._yonkesApi, this._catalogsApi);

  final YonkesApi _yonkesApi;
  final CatalogsApi _catalogsApi;

  @override
  Future<ClientYonkePage> getPage({
    required int page,
    required int pageSize,
    String? search,
    int? cityId,
  }) async {
    final parsed = clientYonkePageFromResponse(
      await _yonkesApi.getPaged(
        page: page,
        pageSize: pageSize,
        search: search,
        cityId: cityId,
      ),
    );
    final items = await Future.wait(
      parsed.items.map((yonke) async {
        if (yonke.ratingCount > 0) return yonke;
        try {
          final reputation = reputationFromResponse(
            await _yonkesApi.getRatings(yonke.id),
          );
          return yonke.withRating(
            average: reputation.average,
            count: reputation.count,
          );
        } catch (_) {
          return yonke;
        }
      }),
    );
    return ClientYonkePage(
      items: items,
      page: parsed.page,
      pageCount: parsed.pageCount,
    );
  }

  @override
  Future<List<ClientYonkeCity>> getCities() async {
    final states = clientYonkeRecords(await _catalogsApi.getStates());
    final groups = await Future.wait(
      states.whereType<Map>().map((state) async {
        final id = state['id'];
        final name = state['entidad']?.toString().trim();
        if (id is! int || name == null || name.isEmpty) {
          return const <ClientYonkeCity>[];
        }
        return clientYonkeCitiesFromRecords(
          clientYonkeRecords(await _catalogsApi.getCitiesByState(id)),
          state: name,
        );
      }),
    );
    final cities = groups.expand((group) => group).toList();
    cities.sort((a, b) => a.label.compareTo(b.label));
    return cities;
  }

  @override
  Future<ClientYonkeDetail> getDetail(ClientYonke initial) async {
    var yonke = initial;
    try {
      yonke =
          clientYonkeFromResponse(await _yonkesApi.getById(initial.id)) ??
          initial;
    } catch (_) {
      // Los datos de la lista permanecen visibles si falla el detalle.
    }
    var comments = const <String>[];
    try {
      final reputation = reputationFromResponse(
        await _yonkesApi.getRatings(initial.id),
      );
      yonke = yonke.withRating(
        average: reputation.average,
        count: reputation.count,
      );
      comments = reputation.comments
          .map((record) => record.comment!)
          .toList(growable: false);
    } catch (_) {
      // La falta de reseñas no impide mostrar el perfil.
    }
    var coverage = const <String>[];
    try {
      coverage = clientYonkeCoverageFromResponse(
        await _yonkesApi.getCoverage(initial.id),
      );
    } catch (_) {
      // La cobertura se presenta como no disponible si el endpoint falla.
    }
    return ClientYonkeDetail(
      yonke: yonke,
      ratingComments: comments,
      coverage: coverage,
    );
  }
}
