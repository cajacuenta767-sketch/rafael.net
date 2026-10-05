import 'package:flutter/material.dart';

import 'adaptive_navigation.dart';

/// Limits reading width without changing routes, text scaling or API state.
/// The actual Scaffold remains the ancestor used by sheets and snackbars.
class ResponsiveScaffold extends StatefulWidget {
  const ResponsiveScaffold({
    super.key,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.maxContentWidth = 1200,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final double maxContentWidth;

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  final _bodyKey = GlobalKey();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, window) {
      final appBar = widget.appBar;
      final body = widget.body;
      final backgroundColor = widget.backgroundColor;
      final bottomNavigationBar = widget.bottomNavigationBar;
      final floatingActionButton = widget.floatingActionButton;
      final resizeToAvoidBottomInset = widget.resizeToAvoidBottomInset;
      final maxContentWidth = widget.maxContentWidth;
      final navigation = bottomNavigationBar;
      final sideNavigation =
          window.maxWidth >= 1200 && navigation is AdaptiveNavigation;
      final content = body == null
          ? null
          : ResponsiveContent(
              maxWidth: maxContentWidth,
              child: LayoutBuilder(
                builder: (context, box) {
                  final minimum =
                      240 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
                  final height = box.maxHeight < minimum
                      ? minimum
                      : box.maxHeight;
                  return SingleChildScrollView(
                    physics: height > box.maxHeight
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      height: height,
                      child: KeyedSubtree(key: _bodyKey, child: body),
                    ),
                  );
                },
              ),
            );
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: sideNavigation
            ? Row(
                children: [
                  (navigation as AdaptiveNavigation).buildSideNavigation(
                    context,
                  ),
                  Expanded(child: content ?? const SizedBox()),
                ],
              )
            : content,
        bottomNavigationBar: sideNavigation || bottomNavigationBar == null
            ? null
            : ResponsiveContent(
                maxWidth: maxContentWidth,
                child: bottomNavigationBar,
              ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: _ContentFloatingActionButtonLocation(
          maxContentWidth,
        ),
      );
    },
  );
}

class _ContentFloatingActionButtonLocation
    extends FloatingActionButtonLocation {
  const _ContentFloatingActionButtonLocation(this.maxWidth);
  final double maxWidth;
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final standard = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    final width = geometry.scaffoldSize.width;
    final gutter = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
    final x = geometry.textDirection == TextDirection.rtl
        ? standard.dx + gutter
        : standard.dx - gutter;
    return Offset(x, standard.dy);
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 960,
  });
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Reflows cards by their available width and the user's text preference.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.spacing = 12,
  });
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final items = children
          .where((child) => child is! SizedBox || child.child != null)
          .map((child) => child is Expanded ? child.child : child)
          .toList();
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      final columns =
          ((box.maxWidth + spacing) / (minItemWidth * scale + spacing))
              .floor()
              .clamp(1, items.length);
      final width = (box.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final item in items) SizedBox(width: width, child: item),
        ],
      );
    },
  );
}

/// Keeps a horizontal arrangement at normal sizes and gives enlarged text
/// its own lines in narrow windows. Never scales the user's text down.
class AdaptiveInline extends StatelessWidget {
  const AdaptiveInline({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.minimumInlineWidth = 240,
  });
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double minimumInlineWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < minimumInlineWidth ||
          (box.maxWidth < 600 &&
              MediaQuery.textScalerOf(context).scale(1) > 1.3)) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final child in children)
              if (child is! Spacer &&
                  (child is! SizedBox || child.child != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: child is Flexible
                      ? child.child
                      : child is SizedBox && child.child != null
                      ? child.child!
                      : child,
                ),
          ],
        );
      }
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    },
  );
}
