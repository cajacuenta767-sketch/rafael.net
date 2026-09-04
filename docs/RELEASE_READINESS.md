# Preparación para publicar refaNet

Revisión realizada el 4 de septiembre de 2026. Este documento separa los
ajustes que ya pueden hacerse en la aplicación de las decisiones que deben
confirmar los propietarios del producto y del backend.

## Configuración ya preparada

- Nombre visible `refaNet` en Android y iOS.
- Permiso de Internet para comunicarse con la API.
- Descripciones de privacidad de cámara y galería en iOS.
- Copias locales de términos y aviso de privacidad.
- Tokens previstos en almacenamiento seguro.
- Copias de seguridad de la aplicación deshabilitadas en Android.
- Logs de red desactivados por defecto.

El permiso de notificaciones de Android no se declara todavía. Debe agregarse
cuando Firebase y el flujo real de notificaciones estén completos; solicitarlo
antes sería pedir al usuario acceso para una función que aún no existe.

## Decisiones necesarias antes de generar una versión de tienda

1. **Identificador definitivo de la aplicación.** Android e iOS todavía usan
   identificadores `com.example`. No deben cambiarse hasta que el propietario
   confirme el dominio o nombre único, porque después de publicar no se puede
   sustituir sin crear otra aplicación en la tienda.
2. **Firma de Android.** La compilación release todavía utiliza la firma de
   depuración. Se necesita crear y custodiar un keystore de producción fuera
   del repositorio.
3. **Cuenta y firma de Apple.** Deben definirse Apple Developer Team, Bundle ID,
   certificados y perfiles de aprovisionamiento.
4. **Icono final.** Los iconos instalables siguen siendo los predeterminados de
   Flutter. Debe aprobarse una versión cuadrada del símbolo de refaNet antes de
   reemplazar todos los tamaños de Android e iOS.
5. **Autenticación social.** Google y Apple deben configurarse con los
   identificadores definitivos de la aplicación. Apple Sign In no debe
   activarse en producción hasta tener su entitlement y contrato de sesión.
6. **Notificaciones.** Firebase, APNs, permisos y registro de dispositivo deben
   añadirse únicamente cuando el backend documente sus respuestas y exista una
   política de envío.

## Dependencias del backend

Las funciones que no tienen una respuesta definida en Swagger permanecen en
modo de prueba o bloqueadas. La lista contractual está en
`docs/BACKEND_CONTRACT_CHECKLIST.md`.

## Control previo a cada publicación

- Ejecutar análisis estático y todas las pruebas automáticas.
- Generar una compilación Android release firmada y probarla en un dispositivo
  físico.
- Generar un Archive de iOS y validarlo en Xcode.
- Confirmar que el modo de prueba esté desactivado.
- Confirmar URL y ambiente de API de producción.
- Revisar textos legales, ficha de privacidad y política de eliminación de
  cuenta.
- Verificar cámara, galería, enlaces externos y cierre de sesión en Android e
  iOS.
