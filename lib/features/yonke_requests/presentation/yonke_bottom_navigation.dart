import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/adaptive_navigation.dart';
import '../../../app/theme/yonke_theme.dart';

enum YonkeNavigationSection { home, requests, quotes, messages, profile }

class YonkeBottomNavigation extends StatelessWidget
    implements AdaptiveNavigation {
  const YonkeBottomNavigation({
    super.key,
    required this.onRefresh,
    required this.selected,
  });

  final VoidCallback onRefresh;
  final YonkeNavigationSection selected;

  @override
  Widget buildSideNavigation(BuildContext context) => SideNavigation(
    background: YonkeColors.primaryNavy,
    labels: const [
      'Solicitudes',
      'Cotizaciones',
      'Nueva Cotización (+)',
      'Mensajes',
      'Perfil',
    ],
    icons: const [
      Icons.assignment_outlined,
      Icons.inventory_2_outlined,
      Icons.add_circle_outline,
      Icons.chat_bubble_outline,
      Icons.person_outline,
    ],
    selectedIndex: switch (selected) {
      YonkeNavigationSection.requests => 0,
      YonkeNavigationSection.quotes => 1,
      YonkeNavigationSection.messages => 3,
      YonkeNavigationSection.profile => 4,
      YonkeNavigationSection.home => -1,
    },
    onSelect: (index) {
      if (index == 2) {
        _showQuoteActions(context);
        return;
      }
      final route = [
        AppRoutes.yonkeRequests,
        AppRoutes.yonkeQuotes,
        AppRoutes.yonkeRequests,
        AppRoutes.yonkeMessages,
        AppRoutes.yonkeProfile,
      ][index];
      context.go(route);
    },
  );

  @override
  Widget build(BuildContext context) => Material(
    color: YonkeColors.primaryNavy,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height:
            78 +
            (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) - 1) *
                32,
        child: Row(
          children: [
            _YonkeNavItem(
              icon: Icons.assignment_outlined,
              label: 'Solicitudes',
              selected: selected == YonkeNavigationSection.requests ||
                  selected == YonkeNavigationSection.home,
              onTap: selected == YonkeNavigationSection.home
                  ? null
                  : () => context.go(AppRoutes.yonkeHome),
            ),
            _YonkeNavItem(
              icon: Icons.inventory_2_outlined,
              label: 'Cotizaciones',
              selected: selected == YonkeNavigationSection.quotes,
              onTap: selected == YonkeNavigationSection.quotes
                  ? null
                  : () => context.go(AppRoutes.yonkeQuotes),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Nueva cotización',
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
              icon: Icons.person_outline,
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
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
                  subtitle: const Text(
                    'Elige primero la pieza que responderás',
                  ),
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
                  ? YonkeColors.accentGreen
                  : const Color(0xFFB0BDD0),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: MediaQuery.textScalerOf(context).scale(1) > 1
                  ? Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? YonkeColors.accentGreen
                            : const Color(0xFFB0BDD0),
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? YonkeColors.accentGreen
                              : const Color(0xFFB0BDD0),
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
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
