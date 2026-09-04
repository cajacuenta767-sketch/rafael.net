import '../../yonkes/data/yonkes_api.dart';
import '../domain/yonke_notification.dart';

abstract interface class YonkeNotificationsRepository {
  Future<YonkeNotificationSnapshot> load({
    required bool isDemoSession,
    required String? yonkeId,
  });

  /// El token se obtendrá con Firebase Messaging una vez configurado. Este
  /// método deja preparada la llamada real sin generar tokens ficticios.
  Future<void> registerDevice({
    required String yonkeId,
    required String firebaseToken,
    required String platform,
    required String model,
  });
}

class ApiYonkeNotificationsRepository implements YonkeNotificationsRepository {
  const ApiYonkeNotificationsRepository(this._yonkesApi);

  final YonkesApi _yonkesApi;

  @override
  Future<YonkeNotificationSnapshot> load({
    required bool isDemoSession,
    required String? yonkeId,
  }) async {
    if (yonkeId == null || yonkeId.isEmpty) {
      throw const YonkeNotificationIdentityPendingException();
    }
    return const YonkeNotificationSnapshot(
      setup: YonkeNotificationSetup.firebasePending,
      notificationsEnabled: false,
      items: [],
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

class DemoYonkeNotificationsRepository implements YonkeNotificationsRepository {
  const DemoYonkeNotificationsRepository();

  @override
  Future<YonkeNotificationSnapshot> load({
    required bool isDemoSession,
    required String? yonkeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return YonkeNotificationSnapshot(
      setup: YonkeNotificationSetup.demoReady,
      notificationsEnabled: true,
      items: [
        YonkeNotificationItem(
          id: 'demo-notification-1',
          title: 'Nueva solicitud',
          body: 'Alternador Nissan Altima 2018 · Nogales, Sonora',
          receivedAt: DateTime(2026, 9, 4, 10, 30),
        ),
      ],
    );
  }

  @override
  Future<void> registerDevice({
    required String yonkeId,
    required String firebaseToken,
    required String platform,
    required String model,
  }) => Future<void>.value();
}
