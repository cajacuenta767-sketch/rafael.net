import '../../../core/storage/token_store.dart';
import '../domain/client_profile.dart';

abstract interface class ClientProfileRepository {
  Future<ClientProfileSnapshot> load();
}

/// Perfil limitado a información confirmada localmente.
///
/// El Swagger actual no publica una operación para consultar o actualizar el
/// perfil del cliente. Por eso esta implementación no inventa datos ni simula
/// una respuesta del servidor.
class LocalClientProfileRepository implements ClientProfileRepository {
  const LocalClientProfileRepository({
    required this.tokenStore,
    required this.demoMode,
  });

  final TokenStore tokenStore;
  final bool demoMode;

  @override
  Future<ClientProfileSnapshot> load() async {
    if (demoMode) {
      return const ClientProfileSnapshot(
        availability: ClientProfileAvailability.demo,
      );
    }

    final token = await tokenStore.readAccessToken();
    if (token == null || token.isEmpty) {
      return const ClientProfileSnapshot(
        availability: ClientProfileAvailability.unavailable,
      );
    }

    return const ClientProfileSnapshot(
      availability: ClientProfileAvailability.unavailable,
    );
  }
}
