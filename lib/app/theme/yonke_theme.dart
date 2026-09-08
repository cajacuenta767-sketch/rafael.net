import 'package:flutter/material.dart';

/// Colores y recursos comunes de la experiencia para yonkes.
///
/// Son constantes para que puedan usarse dentro de widgets `const` y se
/// mantenga el mismo aspecto en todas las pantallas del módulo.
abstract final class YonkeColors {
  // Azul vivo tomado del acceso "Soy Yonke" de la guía visual.
  static const primaryNavy = Color(0xFF164FAE);
  static const accentGreen = Color(0xFF28A745);
  static const background = Color(0xFFFAFBFD);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF596276);
  static const border = Color(0xFFE1E6EC);
}

abstract final class YonkeAssets {
  static const icon = 'assets/images/refanet_yonke_icon.png';
  static const logo = 'assets/images/refanet_yonke_logo.png';
  static const logoTransparent =
      'assets/images/refanet_yonke_logo_transparent.png';
}
