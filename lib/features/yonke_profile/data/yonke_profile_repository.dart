import '../../../core/storage/token_store.dart';
import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_profile.dart';

abstract interface class YonkeProfileRepository {
  Future<YonkeProfileSnapshot> load();
}

/// Perfil del yonke autenticado con `GET /api/Yonkes/{guidId}`, usando el
/// `yonkeGuidId` que el login guardó en el almacenamiento seguro. Sin ese
/// identificador no se consulta el perfil de otro negocio.
class ApiYonkeProfileRepository implements YonkeProfileRepository {
  const ApiYonkeProfileRepository(this._yonkesApi, this._tokenStore);

  final YonkesApi _yonkesApi;
  final TokenStore _tokenStore;

  @override
  Future<YonkeProfileSnapshot> load() async {
    final yonkeId = await _tokenStore.readYonkeGuidId();
    if (yonkeId == null || yonkeId.isEmpty) {
      return const YonkeProfileSnapshot(
        availability: YonkeProfileAvailability.identityPending,
      );
    }
    final response = await _yonkesApi.getById(yonkeId);
    final profile = yonkeProfileFromResponse(response);
    if (profile == null) {
      throw StateError('La respuesta de Yonkes/{guidId} no trae el perfil.');
    }
    return YonkeProfileSnapshot(
      availability: YonkeProfileAvailability.available,
      profile: profile,
    );
  }
}
