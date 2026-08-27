# Refanet Yonke

Aplicación Flutter para Android y iOS preparada para los flujos de cliente y
yonke de la API Refanet.

## Estado

La infraestructura, navegación y módulos HTTP están preparados. La API aún está
en desarrollo, por lo que las respuestas permanecen flexibles hasta que el
contrato OpenAPI defina modelos y errores estables.

## Ejecutar

```shell
flutter pub get
flutter run
```

## Guía completa para contratistas

Esta guía permite descargar, ejecutar y probar el proyecto en una computadora
Windows y un celular Android.

### 1. Obtener acceso al repositorio

El repositorio puede ser privado. El propietario debe agregar tu cuenta de
GitHub como colaborador:

1. Abre el repositorio en GitHub.
2. Ve a **Settings > Collaborators**.
3. Selecciona **Add people** e invita la cuenta del contratista.
4. El contratista debe aceptar la invitación recibida por GitHub.

Repositorio: <https://github.com/ngamez84/refanet_appmobil>

### 2. Instalar las herramientas necesarias

En Windows instala las siguientes herramientas:

- [Flutter SDK estable](https://docs.flutter.dev/get-started/install/windows).
- [Android Studio](https://developer.android.com/studio), incluyendo Android
  SDK y Android SDK Platform-Tools.
- [Git](https://git-scm.com/downloads).

Abre PowerShell y comprueba la instalación:

```powershell
flutter doctor
```

Flutter y **Android toolchain** deben aparecer correctos. Si Flutter pide
aceptar licencias Android, ejecuta:

```powershell
flutter doctor --android-licenses
```

Acepta todas las licencias. En Windows debe estar activado el **Modo
desarrollador** para que Flutter pueda crear enlaces requeridos por plugins.

### 3. Descargar el proyecto

Abre PowerShell en la carpeta donde guardarás el proyecto y ejecuta:

```powershell
git clone https://github.com/ngamez84/refanet_appmobil.git
cd refanet_appmobil
flutter pub get
```

También puedes abrir la carpeta `refanet_appmobil` directamente con Android
Studio y esperar a que termine la sincronización.

### 4. Preparar un celular Android

En el teléfono:

1. Ve a **Ajustes > Acerca del teléfono**.
2. Pulsa siete veces sobre **Número de compilación**.
3. Vuelve a Ajustes y abre **Opciones de desarrollador**.
4. Activa **Depuración USB**.
5. Conecta el celular con un cable USB.
6. Acepta en el teléfono el mensaje de autorización RSA.

Desde la carpeta del proyecto, confirma que Flutter detectó el dispositivo:

```powershell
flutter devices
```

Debe aparecer el modelo del teléfono. Si no aparece, revisa el cable USB,
la depuración USB y la autorización mostrada en el celular.

### 5. Ejecutar en el celular

Desde la carpeta del proyecto:

```powershell
flutter run
```

Si hay varios dispositivos, Flutter pedirá elegir uno: selecciona el número
correspondiente al teléfono Android.

Desde Android Studio:

1. Abre la carpeta del proyecto.
2. Espera a que finalice la sincronización de Flutter.
3. Selecciona el celular en el selector superior.
4. Pulsa el botón verde **Run**.

La primera compilación puede tardar porque Gradle descarga herramientas de
Android y dependencias. Las ejecuciones posteriores serán más rápidas.

### 6. Probar el acceso por SMS

El flujo OTP de cliente está conectado a la API publicada de refaNet:

1. Selecciona **México** en el selector de país.
2. Ingresa los diez dígitos del celular, sin `+52`.
3. Pulsa **Enviar código**.
4. Escribe o pega el código SMS de seis dígitos.

La entrega de SMS está confirmada para números mexicanos. Para una prueba real
utiliza únicamente un número autorizado por el cliente o por el equipo de
desarrollo. No pruebes números ajenos encontrados en Internet.

### 7. Estado de Google y Apple

Los botones de Google y Apple están incluidos en la interfaz.

- **Google**: requiere que el proyecto de Google Cloud registre la aplicación
  Android con su nombre de paquete y certificado SHA-1, además de que el
  backend valide el `idToken` recibido.
- **Apple**: debe configurarse y probarse desde una Mac, porque iOS no se
  compila ni firma desde Windows.

No agregues contraseñas, Client Secrets, API keys privadas ni archivos de
credenciales al repositorio.

### 8. Problemas frecuentes

Si Flutter indica que falta `.dart_tool/package_config.json`:

```powershell
flutter clean
flutter pub get
flutter run
```

Si `flutter run` muestra varios dispositivos, selecciona el teléfono Android.
Si el teléfono no aparece, ejecuta `flutter devices` y revisa los pasos de la
sección 4.

Si necesitas más detalle sobre la configuración local, ejecuta:

```powershell
flutter doctor -v
```

### 9. Actualizar el proyecto

Antes de continuar un trabajo ya iniciado, descarga los últimos cambios:

```powershell
git pull origin main
flutter pub get
flutter run
```

Para seleccionar otro backend:

```shell
flutter run --dart-define=API_BASE_URL=https://servidor.example.com
```

En Windows debe estar activado **Modo desarrollador** para que Flutter pueda
crear los enlaces de los plugins durante `flutter pub get`.

## Documentación

- [Arquitectura e integración API](docs/API_INTEGRATION.md)
- [Pendientes del contrato backend](docs/BACKEND_CONTRACT_CHECKLIST.md)

## Publicación

Antes de generar builds de tienda se deben definir el identificador final del
paquete, firma Android, equipo Apple, iconos, política de privacidad y
configuraciones de Google, Apple, Firebase y Stripe.
