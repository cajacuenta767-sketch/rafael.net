# Configuración de pruebas conectadas

La plantilla `config/app.staging.example.json` contiene exclusivamente configuración cliente y placeholders. Crear una copia local `config/app.staging.json`, sustituir el host por staging autorizado y completar los identificadores públicos aplicables. La plantilla no es una configuración funcional ni crea usuarios.

Ejecutar `flutter run --dart-define-from-file=config/app.staging.json`. Flutter recibe estos valores durante compilación; no interpreta un archivo `.env` automáticamente. Para producción preparar una configuración separada con `APP_ENV=production`, host real y registros de red desactivados.

Nunca incluir claves de firma JWT, claves secretas Stripe, secretos webhook, contraseñas o tokens de usuarios en esta plantilla o en Dart. Los identificadores OAuth y la configuración cliente Firebase no sustituyen las credenciales del servidor ni su autorización.

Para cerrar E2E falta proporcionar de forma autorizada: staging, cuentas cliente/Yonke y permisos definidos, DTO reales de sesión/orden/Checkout/resultado, URLs de retorno, eventos webhook y modelo comercial. Estos datos se coordinan fuera de documentos públicos; los secretos se configuran en el servidor.

La app no crea un JWT válido por disponer de una cuenta Google/GitHub. No usar el backend de producción como staging ni introducir un bypass de OTP para superar pruebas.
