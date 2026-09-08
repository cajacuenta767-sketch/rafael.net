import 'dart:convert';

import 'package:flutter/material.dart';

/// Muestra por igual imágenes HTTPS de producción y recursos locales del
/// mercado de demostración (`asset://assets/...`).
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
