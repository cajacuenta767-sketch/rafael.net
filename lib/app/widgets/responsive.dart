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

/// Relleno para una lista desplazable: su contenido queda centrado y con
/// ancho máximo, sin mover la barra de desplazamiento del borde de la
/// pantalla. Mientras el contenido quepa, el margen lateral es [minSide].
///
/// Pasa [width] cuando conozcas el ancho real (por ejemplo desde un
/// `LayoutBuilder`); si no, se usa el ancho de la pantalla.
EdgeInsets centeredListPadding(
  BuildContext context, {
  double maxWidth = ContentWidth.reading,
  double top = 16,
  double bottom = 24,
  double minSide = 16,
  double? width,
}) {
  final side = sidePadding(
    width ?? MediaQuery.sizeOf(context).width,
    maxWidth: maxWidth,
    minSide: minSide,
  );
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Margen lateral para centrar [maxWidth] dentro de [width].
double sidePadding(
  double width, {
  double maxWidth = ContentWidth.reading,
  double minSide = 16,
}) {
  final centered = (width - maxWidth) / 2;
  return centered > minSide ? centered : minSide;
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

/// Lista de tarjetas que en celular es una columna y en pantallas anchas se
/// reparte en 2 o 3 columnas de igual alto. Construye las filas a medida que
/// se desplaza, como un `ListView.builder`.
class AdaptiveCardList extends StatelessWidget {
  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.footer,
    this.minTileWidth = 360,
    this.maxColumns = 3,
    this.maxWidth = ContentWidth.wide,
    this.singleColumnMaxWidth = ContentWidth.reading,
    this.spacing = 12,
    this.top = 16,
    this.bottom = 28,
    this.minSide = 16,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Contenido fijo arriba de la lista (títulos, filtros), del mismo ancho.
  final Widget? header;
  final Widget? footer;
  final double minTileWidth;
  final int maxColumns;
  final double maxWidth;
  final double singleColumnMaxWidth;
  final double spacing;
  final double top;
  final double bottom;
  final double minSide;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final full = constraints.maxWidth;
      final gutter = Breakpoints.gutter(full) > minSide
          ? Breakpoints.gutter(full)
          : minSide;
      final usable = (full - gutter * 2).clamp(0.0, maxWidth);
      final columns = gridColumns(
        usable,
        minTileWidth: minTileWidth,
        max: maxColumns,
      );
      final contentWidth = columns == 1
          ? usable.clamp(0.0, singleColumnMaxWidth)
          : usable;
      final side = (full - contentWidth) / 2;
      final rowCount = (itemCount / columns).ceil();
      final extra = (header == null ? 0 : 1) + (footer == null ? 0 : 1);
      return ListView.builder(
        controller: controller,
        physics: physics,
        padding: EdgeInsets.fromLTRB(side, top, side, bottom),
        itemCount: rowCount + extra,
        itemBuilder: (context, index) {
          if (header != null) {
            if (index == 0) return header!;
            index -= 1;
          }
          if (index >= rowCount) return footer ?? const SizedBox.shrink();
          final start = index * columns;
          final gap = index == rowCount - 1 ? 0.0 : spacing;
          if (columns == 1) {
            return Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: itemBuilder(context, start),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) SizedBox(width: spacing),
                    Expanded(
                      child: i < itemCount
                          ? itemBuilder(context, i)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Contenedor de los pasos de un flujo (nueva solicitud, fotos, ciudad,
/// revisión). En celular ocupa toda la pantalla como siempre; en tablets,
/// laptops y TV queda como un panel centrado de alto limitado, para que el
/// botón de continuar quede junto al contenido y no al fondo de la pantalla.
class FlowPanel extends StatelessWidget {
  const FlowPanel({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panel = size.width >= Breakpoints.medium && size.height >= 760;
    if (!panel) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth + 32, maxHeight: 860),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE3E7ED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F16233A),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: child,
        ),
      ),
    );
  }
}
