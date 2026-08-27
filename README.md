# Refanet Yonke

Aplicación Flutter para Android y iOS preparada para los flujos de cliente y
yonke de la API Refanet.

## Estado

La infraestructura, navegación y módulos HTTP ya están separados. La API aún
está en desarrollo, por lo que las respuestas permanecen flexibles hasta que el
contrato OpenAPI defina modelos y errores estables.

## Ejecutar

```shell
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
