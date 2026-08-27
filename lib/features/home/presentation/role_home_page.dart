import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';

enum AppRole { client, yonke }

class RoleHomePage extends StatelessWidget {
  const RoleHomePage.client({super.key}) : role = AppRole.client;
  const RoleHomePage.yonke({super.key}) : role = AppRole.yonke;

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final isClient = role == AppRole.client;
    final modules = isClient
        ? const [
            'Autenticación y dispositivo',
            'Nueva solicitud e imágenes',
            'Cotizaciones y mensajes',
            'Órdenes y pagos',
            'Calificaciones',
          ]
        : const [
            'Autenticación de yonke',
            'Dashboard y solicitudes recibidas',
            'Crear y actualizar cotizaciones',
            'Perfil, logotipo y cobertura',
            'Dispositivo y notificaciones',
          ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          isClient && AppConfig.enableMockAuth
              ? 'Cliente · Modo prueba'
              : isClient
              ? 'Cliente'
              : 'Yonke',
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: modules.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline),
          title: Text(modules[index]),
          subtitle: const Text(
            'Módulo preparado para conectar el contrato API.',
          ),
        ),
      ),
    );
  }
}
