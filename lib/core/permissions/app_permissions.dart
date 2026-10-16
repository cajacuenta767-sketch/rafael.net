import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppPermissions {
  static const MethodChannel _channel =
      MethodChannel('com.refanet.app/permissions');

  static Future<void> requestStartupPermissions() async {
    try {
      // 1. Solicitar permisos nativos en Android (Notificaciones, Micrófono, Fotos/Almacenamiento, Cámara)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('requestStartupPermissions');
      }

      // 2. Solicitar permiso de Firebase Messaging para notificaciones remotas
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      } catch (_) {
        // En ambientes sin Google Play Services o pruebas locales no bloquea el flujo
      }
    } catch (_) {
      // Manejo silencioso en plataformas que no admiten el canal o en pruebas de widget
    }
  }
}
