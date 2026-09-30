import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../../app/widgets/responsive.dart';

enum YonkeNavigationSection { home, requests, quotes, messages, profile }

/// Muestra [child] con la barra lateral del yonke en pantallas anchas
/// (tablet horizontal, laptop, monitor, TV). En celulares y tablets en
/// vertical devuelve [child] tal cual y la página usa la barra inferior.
class YonkeNavigationFrame extends StatelessWidget {
  const YonkeNavigationFrame({
    super.key,
    required this.selected,
    required this.child,
  });

  final YonkeNavigationSection selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.useSideNavigation(context)) return child;
    final extended = MediaQuery.sizeOf(context).width >= Breakpoints.large;
    return SideNavigationLayout(
      railWidth: extended ? 232 : 104,
      rail: _YonkeSideNavigation(selected: selected, extended: extended),
      child: child,
    );
  }
}

class _YonkeSideNavigation extends StatelessWidget {
  const _YonkeSideNavigation({required this.selected, required this.extended});

  final YonkeNavigationSection selected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    Widget item(
      YonkeNavigationSection section,
      IconData icon,
      String label,
      String route,
    ) => SideNavigationItem(
      icon: icon,
      label: label,
      selected: selected == section,
      extended: extended,
      selectedColor: const Color(0xFF65D34E),
      color: const Color(0xFFD5DCE8),
      onTap: selected == section ? null : () => context.go(route),
    );
    return Material(
      color: YonkeColors.primaryNavy,
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
                child: Semantics(
                  button: true,
                  label: 'Cotizar una solicitud',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.white,
                    shape: extended
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          )
                        : const CircleBorder(),
                    child: InkWell(
                      customBorder: extended
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            )
                          : const CircleBorder(),
                      onTap: () => context.go(AppRoutes.yonkeRequests),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add,
                              color: YonkeColors.primaryNavy,
                              size: 30,
                            ),
                            if (extended) ...[
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Cotizar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: YonkeColors.primaryNavy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(
                YonkeNavigationSection.home,
                Icons.home_outlined,
                'Inicio',
                AppRoutes.yonkeHome,
              ),
              item(
                YonkeNavigationSection.requests,
                Icons.inbox_outlined,
                'Solicitudes',
                AppRoutes.yonkeRequests,
              ),
              item(
                YonkeNavigationSection.quotes,
                Icons.request_quote_outlined,
                'Cotizaciones',
                AppRoutes.yonkeQuotes,
              ),
              item(
                YonkeNavigationSection.messages,
                Icons.chat_bubble_outline,
                'Mensajes',
                AppRoutes.yonkeMessages,
              ),
              item(
                YonkeNavigationSection.profile,
                Icons.storefront_outlined,
                'Perfil',
                AppRoutes.yonkeProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YonkeBottomNavigation extends StatelessWidget {
  const YonkeBottomNavigation({
    super.key,
    required this.onRefresh,
    required this.selected,
  });

  final VoidCallback onRefresh;
  final YonkeNavigationSection selected;

  @override
  Widget build(BuildContext context) {
    // Con la barra lateral visible la inferior no se muestra.
    if (SideNavigationScope.active(context)) return const SizedBox.shrink();
    return _buildBar(context);
  }

  Widget _buildBar(BuildContext context) => Material(
    color: YonkeColors.primaryNavy,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            _YonkeNavItem(
              icon: Icons.home_outlined,
              label: 'Inicio',
              selected: selected == YonkeNavigationSection.home,
              onTap: selected == YonkeNavigationSection.home
                  ? null
                  : () => context.go(AppRoutes.yonkeHome),
            ),
            _YonkeNavItem(
              icon: Icons.inbox_outlined,
              label: 'Solicitudes',
              selected: selected == YonkeNavigationSection.requests,
              onTap: selected == YonkeNavigationSection.requests
                  ? null
                  : () => context.go(AppRoutes.yonkeRequests),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Abrir centro de cotizaciones',
                child: Center(
                  child: InkWell(
                    onTap: () => _showQuoteActions(context),
                    borderRadius: BorderRadius.circular(31),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE4E9F1),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x45000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: YonkeColors.primaryNavy,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _YonkeNavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Mensajes',
              selected: selected == YonkeNavigationSection.messages,
              onTap: selected == YonkeNavigationSection.messages
                  ? null
                  : () => context.go(AppRoutes.yonkeMessages),
            ),
            _YonkeNavItem(
              icon: Icons.storefront_outlined,
              label: 'Perfil',
              selected: selected == YonkeNavigationSection.profile,
              onTap: selected == YonkeNavigationSection.profile
                  ? null
                  : () => context.go(AppRoutes.yonkeProfile),
            ),
          ],
        ),
      ),
    ),
  );

  void _showQuoteActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Centro de cotizaciones',
                style: TextStyle(
                  color: YonkeColors.primaryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF6EA),
                  child: Icon(
                    Icons.request_quote_outlined,
                    color: Color(0xFF28A745),
                  ),
                ),
                title: const Text('Mis cotizaciones'),
                subtitle: const Text('Consulta las enviadas y aceptadas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(AppRoutes.yonkeQuotes);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDF2F8),
                  child: Icon(Icons.add_task, color: YonkeColors.primaryNavy),
                ),
                title: const Text('Cotizar una solicitud'),
                subtitle: const Text('Elige primero la pieza que responderás'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go(AppRoutes.yonkeRequests);
                },
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onRefresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar esta pantalla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YonkeNavItem extends StatelessWidget {
  const _YonkeNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(0xFF65D34E)
                  : const Color(0xFFD5DCE8),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? const Color(0xFF65D34E)
                        : const Color(0xFFD5DCE8),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
