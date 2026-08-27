# Refanet Yonke

Aplicación Flutter para Android y iOS preparada para los flujos de cliente y
yonke de la API Refanet.

## Estado
está en desarrollo, por lo que las respuestas permanecen flexibles hasta que el
contrato OpenAPI defina modelos y errores estables.

## Ejecutar

```shell
flutter pub get
flutter run
```

## Guía para contratistas

### 1. Obtener acceso y descargar

El repositorio puede ser privado. El propietario debe agregar tu cuenta de
GitHub como colaborador y debes aceptar la invitación.

```powershell
git clone https://github.com/ngamez84/refanet_appmobil.git
cd refanet_appmobil
flutter pub get
```

### 2. Instalar herramientas en Windows

Instala Flutter, Android Studio (con Android SDK) y Git. Después confirma la
instalación:

```powershell
flutter doctor
flutter doctor --android-licenses
```

Acepta las licencias que solicite el segundo comando.

### 3. Preparar un celular Android

1. Ve a **Ajustes > Acerca del teléfono**.
2. Pulsa siete veces **Número de compilación**.
3. En **Opciones de desarrollador**, activa **Depuración USB**.
4. Conecta el teléfono por USB y acepta la autorización mostrada en él.

Comprueba que Flutter lo detecta:

```powershell
flutter devices
```

### 4. Ejecutar la aplicación

```powershell
flutter run
```

Si hay varios dispositivos, elige el número correspondiente al teléfono. En
Android Studio también puedes abrir la carpeta del proyecto, seleccionar el
teléfono y pulsar el botón verde **Run**.

### 5. Probar el acceso por SMS

El acceso OTP está conectado a la API publicada de refaNet:

- Selecciona **México**.
- Ingresa los diez dígitos del celular, sin `+52`.
- Pulsa **Enviar código**.
- Escribe o pega el código SMS de seis dígitos.

La entrega SMS está confirmada para números mexicanos. Para una prueba real,
utiliza solamente un número autorizado por el cliente o equipo de desarrollo.

### 6. Google y Apple

Los botones están incluidos. Google requiere registrar en Google Cloud el
paquete Android y su SHA-1; Apple se configura y prueba desde una Mac. No se
deben agregar secretos ni credenciales de proveedores al repositorio.

### 7. Problemas frecuentes

Si Flutter indica que falta `package_config.json`:

```powershell
flutter clean
flutter pub get
flutter run
```

Si el celular no aparece, revisa el cable USB, la depuración USB y la
autorización del teléfono.

La primera compilación puede tardar mientras Android descarga sus herramientas.
Para actualizar el proyecto después:

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
