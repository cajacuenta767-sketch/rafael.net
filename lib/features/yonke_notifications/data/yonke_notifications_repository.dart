import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_notification.dart';

abstract interface class YonkeNotificationsRepository {
  Future<YonkeNotificationSnapshot> load({required String? yonkeId});

  /// El token se obtendrá con Firebase Messaging una vez configurado. Este
  /// método deja preparada la llamada real sin generar tokens ficticios.
  Future<void> registerDevice({
    required String yonkeId,
    required String firebaseToken,
    required String platform,
    required String model,
  });
}

/// `POST /api/YonkesDispositivos` está listo; falta Firebase Messaging en la
/// app para obtener el token del dispositivo, así que la pantalla informa el
/// estado en lugar de simular avisos.
class ApiYonkeNotificationsRepository implements YonkeNotificationsRepository {
  const ApiYonkeNotificationsRepository(this._yonkesApi);

  final YonkesApi _yonkesApi;

  @override
  Future<YonkeNotificationSnapshot> load({required String? yonkeId}) async {
    if (yonkeId == null || yonkeId.isEmpty) {
      throw const YonkeNotificationIdentityPendingException();
    }
    return const YonkeNotificationSnapshot(
      setup: YonkeNotificationSetup.firebasePending,
    );
  }

  @override
  Future<void> registerDevice({
    required String yonkeId,
    required String firebaseToken,
    required String platform,
    required String model,
  }) => _yonkesApi.registerDevice(
    yonkeId: yonkeId,
    firebaseToken: firebaseToken,
    platform: platform,
    model: model,
  );
}
