import 'package:flutter/material.dart';

/// Tamaños de ventana de Material 3, medidos en dp lógicos.
///
/// - compacto: celulares en vertical (< 600)
/// - mediano: tablets en vertical, plegables abiertos (600 a 839)
/// - expandido: tablets en horizontal, laptops, TV (840 a 1199)
/// - grande: monitores (>= 1200)
enum WindowSize { compact, medium, expanded, large }

abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
  static const large = 1200.0;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= large) return WindowSize.large;
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  /// La navegación pasa de la barra inferior a una barra lateral.
  static bool useSideNavigation(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  /// Margen lateral del contenido según el ancho disponible.
  static double gutter(double width) {
    if (width >= large) return 40;
    if (width >= expanded) return 32;
    if (width >= medium) return 24;
    return 16;
  }

  /// La letra del sistema está agrandada (accesibilidad).
  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.25;
}

/// Anchos máximos del contenido según el tipo de pantalla.
abstract final class ContentWidth {
  /// Formularios y pasos de un flujo.
  static const form = 600.0;

  /// Detalles y textos para leer.
  static const reading = 760.0;

  /// Conversaciones.
  static const chat = 880.0;

  /// Listas, tableros y cuadrículas.
  static const wide = 1200.0;
}

/// Centra el contenido y lo limita a [maxWidth], con un margen lateral que
/// crece con la pantalla. Úsalo como hijo directo del `body`.
class AppContent extends StatelessWidget {
  const AppContent({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.reading,
    this.padding = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;

  /// Agrega el margen lateral adaptable.
  final bool padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = padding ? Breakpoints.gutter(width) : 0.0;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

/// Envuelve una lista desplazable para que su contenido quede centrado y con
/// ancho máximo, sin mover la barra de desplazamiento del borde de la pantalla.
EdgeInsets centeredListPadding(
  BuildContext context, {
  double maxWidth = ContentWidth.reading,
  double top = 16,
  double bottom = 24,
  double minSide = 16,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = Breakpoints.gutter(width) > minSide
      ? Breakpoints.gutter(width)
      : minSide;
  final side = width > maxWidth + gutter * 2 ? (width - maxWidth) / 2 : gutter;
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Número de columnas de una cuadrícula de tarjetas según el ancho útil.
int gridColumns(double width, {double minTileWidth = 340, int max = 3}) {
  final columns = (width / minTileWidth).floor();
  if (columns < 1) return 1;
  return columns > max ? max : columns;
}

/// Acomoda [children] en columnas de igual ancho; en pantallas angostas queda
/// una sola columna.
class ResponsiveWrapGrid extends StatelessWidget {
  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.minTileWidth = 340,
    this.maxColumns = 3,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = gridColumns(
        constraints.maxWidth,
        minTileWidth: minTileWidth,
        max: maxColumns,
      );
      if (columns == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        );
      }
      final rows = <Widget>[];
      for (var start = 0; start < children.length; start += columns) {
        final end = start + columns > children.length
            ? children.length
            : start + columns;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) SizedBox(width: spacing),
                Expanded(
                  child: i < end ? children[i] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            rows[i],
          ],
        ],
      );
    },
  );
}

/// Indica a la barra inferior que ya hay una barra lateral visible, para no
/// mostrar las dos.
class SideNavigationScope extends InheritedWidget {
  const SideNavigationScope({super.key, required super.child});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SideNavigationScope>() !=
      null;

  @override
  bool updateShouldNotify(SideNavigationScope oldWidget) => false;
}

/// Pone [rail] a la izquierda de [child] y le informa a [child] el ancho que
/// realmente le queda, para que sus cálculos de tamaño sean correctos.
class SideNavigationLayout extends StatelessWidget {
  const SideNavigationLayout({
    super.key,
    required this.rail,
    required this.railWidth,
    required this.child,
  });

  final Widget rail;
  final double railWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rest = media.size.width - railWidth;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: railWidth, child: rail),
        Expanded(
          child: MediaQuery(
            data: media.copyWith(
              size: Size(rest < 0 ? 0 : rest, media.size.height),
              padding: media.padding.copyWith(left: 0),
              viewPadding: media.viewPadding.copyWith(left: 0),
            ),
            child: SideNavigationScope(child: child),
          ),
        ),
      ],
    );
  }
}

/// Elemento de una barra lateral: ícono con su nombre debajo, o a la derecha
/// cuando la barra es ancha.
class SideNavigationItem extends StatelessWidget {
  const SideNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    required this.selectedColor,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback? onTap;
  final Color selectedColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? selectedColor : color;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tint,
        fontSize: extended ? 15 : 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: selected ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 4,
                  vertical: 8,
                ),
                child: extended
                    ? Row(
                        children: [
                          Icon(icon, color: tint),
                          const SizedBox(width: 14),
                          Expanded(child: text),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: tint),
                          const SizedBox(height: 4),
                          text,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
