# Configuración release Android

La configuración release ya no usa la firma debug. Copiar `android/key.properties.example` a `android/key.properties` y completar con la clave privada autorizada de distribución. El archivo real y los keystores están excluidos de Git. No copiar claves ni contraseñas a este documento, chats o capturas.

Si la app ya fue publicada, preservar su continuidad de firma; no generar o reemplazar una clave por conveniencia. Debug sigue utilizando su configuración de desarrollo. Sin la clave privada, una release firmada queda pendiente y no debe describirse como entregada.

Verificar build y certificado de salida con la clave autorizada antes de publicar. Referencia: [Flutter — firma Android](https://docs.flutter.dev/deployment/android#sign-the-app).
