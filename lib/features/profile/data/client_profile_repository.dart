import '../../../core/storage/token_store.dart';
import '../domain/client_profile.dart';

abstract interface class ClientProfileRepository {
  Future<ClientProfileSnapshot> load();
}

/// Perfil limitado a información confirmada localmente.
///
/// El OpenAPI no publica una operación para consultar o actualizar el perfil
/// del cliente, así que no se inventan datos ni se simula una respuesta.
class LocalClientProfileRepository implements ClientProfileRepository {
  const LocalClientProfileRepository({required this.tokenStore});

  final TokenStore tokenStore;

  @override
  Future<ClientProfileSnapshot> load() async {
    await tokenStore.readAccessToken();
    return const ClientProfileSnapshot(
      availability: ClientProfileAvailability.unavailable,
    );
  }
}
