# Refanet Yonke (app_yonke)

Aplicación Flutter (Android/iOS) para los flujos de cliente y yonke de la API
Refanet. Sin modo demo: todas las pantallas consumen la API publicada.

## Requisitos

- Flutter 3.47.x estable (Dart >= 3.13, Flutter >= 3.44 según `pubspec.lock`).
- En Claude Code en la web, `.claude/hooks/session-start.sh` instala Flutter en
  `/opt/flutter`, lo agrega al PATH y ejecuta `flutter pub get` al iniciar.

## Comandos

```shell
flutter pub get        # dependencias
flutter analyze        # análisis estático (CI exige cero incidencias)
dart format .          # formato (en CI es informativo)
flutter test           # todas las pruebas
flutter test test/session_payload_test.dart   # una sola prueba
dart run tool/api_probe.dart --token=<jwt>     # sonda del contrato de la API
```

Otro backend: `flutter run --dart-define=API_BASE_URL=https://servidor`.

## Estructura

- `lib/core/` configuración, cliente HTTP (Dio), almacenamiento seguro y DI
  (Riverpod).
- `lib/features/<módulo>/{data,domain,presentation}` un módulo por pantalla o
  flujo; navegación con `go_router` en `lib/app/router/app_router.dart`.
- `test/` pruebas de widgets, parsers del contrato y capturas de referencia en
  `test/goldens/`.
- `docs/` contrato OpenAPI (`openapi_v1.json`), mapa de endpoints por pantalla
  y pendientes del backend.

## Notas

- No agregar credenciales, API keys ni keystores al repositorio.
- Las tres pruebas golden (`client_chat`, `client_profile`, `client_yonkes`)
  comparan PNG generados en otro sistema operativo; en Linux (CI y este
  entorno) fallan por diferencias de renderizado de texto. Para regenerarlas en
  Linux: `flutter test --update-goldens`.
- Seis pruebas de captura (`yonke_*_screenshot_test.dart`) escriben PNG en una
  ruta absoluta de Windows (`C:\Users\PC\...`); en Linux dejan archivos con ese
  nombre literal en la raíz del repositorio. No confirmarlos; bórralos tras
  ejecutar `flutter test`.
- CI (`.github/workflows/ci.yml`): `flutter pub get`, formato informativo,
  `flutter analyze` y `flutter test`.
