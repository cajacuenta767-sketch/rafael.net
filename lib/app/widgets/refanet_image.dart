import 'dart:convert';

import 'package:flutter/material.dart';

/// Muestra imágenes HTTPS de la API, imágenes en base64 y recursos locales
/// empaquetados (`asset://assets/...`), con un `fallback` si no se pueden
/// cargar.
class RefanetImage extends StatelessWidget {
  const RefanetImage({
    super.key,
    required this.source,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? source;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return fallback;
    if (value.startsWith('asset://assets/')) {
      return Image.asset(
        value.substring('asset://'.length),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (value.startsWith('data:image/') && value.contains(';base64,')) {
      try {
        return Image.memory(
          base64Decode(value.split(';base64,').last),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    return Image.network(
      value,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
