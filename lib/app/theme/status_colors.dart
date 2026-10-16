import 'package:flutter/material.dart';

/// Guía y sistema unificado de colores de estatus para Cliente y Yonke.
abstract final class AppStatusColors {
  // Verde: Aceptada, Pagada, Entregada, Nueva (éxito)
  static const success = Color(0xFF147A1D);

  // Azul: En proceso, Enviada, Cotizada, Vista, Mensajes (activo/informativo)
  static const info = Color(0xFF114EB0);

  // Ámbar: Pendiente, En revisión (atención)
  static const warning = Color(0xFFD97706);

  // Rojo: Cancelada, Rechazada, Error, Falla (alerta/fallo)
  static const danger = Color(0xFFB3261E);

  // Gris: Cerrada, Descartada, Histórico (neutro)
  static const neutral = Color(0xFF596276);

  /// Resuelve el color acorde al texto del estado.
  static Color fromStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s.contains('acept') ||
        s.contains('camino') ||
        s.contains('complet') ||
        s.contains('entreg') ||
        s.contains('recibid') ||
        s.contains('pagad') ||
        s.contains('nueva') ||
        s.contains('exito') ||
        s.contains('aprob')) {
      return success;
    }
    if (s.contains('proceso') ||
        s.contains('envi') ||
        s.contains('cotiz') ||
        s.contains('activ') ||
        s.contains('vista') ||
        s.contains('mensaj')) {
      return info;
    }
    if (s.contains('pend') || s.contains('revis')) {
      return warning;
    }
    if (s.contains('cancel') ||
        s.contains('rechaz') ||
        s.contains('error') ||
        s.contains('fall')) {
      return danger;
    }
    return neutral;
  }

  /// Píldora de estado reutilizable con tipografía y fondo acordes al diseño.
  static Widget badge(
    String status, {
    bool uppercase = false,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w800,
  }) {
    final color = fromStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        uppercase ? status.toUpperCase() : status,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
