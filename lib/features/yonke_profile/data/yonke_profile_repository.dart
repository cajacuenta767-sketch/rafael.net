import '../../../core/storage/token_store.dart';
import '../domain/yonke_profile.dart';

abstract interface class YonkeProfileRepository {
  Future<YonkeProfileSnapshot> load();
}

/// El contrato actual ofrece operaciones por id de yonke, pero el inicio de
/// sesión aún no documenta cómo obtener ese id ni el perfil autenticado.
/// Por seguridad, no se consulta ni actualiza un perfil adivinando su id.
class LocalYonkeProfileRepository implements YonkeProfileRepository {
  const LocalYonkeProfileRepository({
    required this.tokenStore,
    required this.isDemoSession,
  });

  final TokenStore tokenStore;
  final bool isDemoSession;

  @override
  Future<YonkeProfileSnapshot> load() async {
    if (isDemoSession) {
      return const YonkeProfileSnapshot(
        availability: YonkeProfileAvailability.demo,
      );
    }
    await tokenStore.readAccessToken();
    return const YonkeProfileSnapshot(
      availability: YonkeProfileAvailability.contractPending,
    );
  }
}
