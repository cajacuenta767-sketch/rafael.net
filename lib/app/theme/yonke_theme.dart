import 'package:flutter/material.dart';

/// Colores y recursos comunes de la experiencia para yonkes.
///
/// Son constantes para que puedan usarse dentro de widgets `const` y se
/// mantenga el mismo aspecto en todas las pantallas del módulo.
abstract final class YonkeColors {
  // Azul Marino corporativo oficial de la maqueta (#0D1B3D)
  static const primaryNavy = Color(0xFF0D1B3D);
  static const accentGreen = Color(0xFF28A745);
  static const background = Color(0xFFFAFBFD);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF596276);
  static const border = Color(0xFFE1E6EC);

  // Badges y píldoras de estado
  static const badgeNuevaText = Color(0xFF28A745);
  static const badgeNuevaBg = Color(0xFFE8F5E9);
  static const badgeEnRevisionText = Color(0xFF1976D2);
  static const badgeEnRevisionBg = Color(0xFFE3F2FD);
  static const badgeCotizadaText = Color(0xFF607D8B);
  static const badgeCotizadaBg = Color(0xFFECEFF1);
}

abstract final class YonkeAssets {
  static const icon = 'assets/images/refanet_yonke_icon.png';
  static const logo = 'assets/images/refanet_yonke_logo.png';
  static const logoTransparent =
      'assets/images/refanet_yonke_logo_transparent.png';
}
