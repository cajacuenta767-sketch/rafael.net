import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

enum YonkeNavigationSection { requests, quotes, messages, profile }

class YonkeBottomNavigation extends StatelessWidget {
  const YonkeBottomNavigation({
    super.key,
    required this.onRefresh,
    required this.selected,
    required this.isDemoSession,
  });

  final VoidCallback onRefresh;
  final YonkeNavigationSection selected;
  final bool isDemoSession;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            _YonkeNavItem(
              icon: Icons.inbox_outlined,
              label: 'Solicitudes',
              selected: selected == YonkeNavigationSection.requests,
              onTap: selected == YonkeNavigationSection.requests
                  ? null
                  : () => context.go(AppRoutes.yonkeHome, extra: isDemoSession),
            ),
            _YonkeNavItem(
              icon: Icons.request_quote_outlined,
              label: 'Cotizaciones',
              selected: selected == YonkeNavigationSection.quotes,
              onTap: selected == YonkeNavigationSection.quotes
                  ? null
                  : () =>
                        context.go(AppRoutes.yonkeQuotes, extra: isDemoSession),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Actualizar solicitudes',
                child: Center(
                  child: InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF114EB0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 28,
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
                  : () => context.go(
                      AppRoutes.yonkeMessages,
                      extra: isDemoSession,
                    ),
            ),
            _YonkeNavItem(
              icon: Icons.storefront_outlined,
              label: 'Perfil',
              selected: selected == YonkeNavigationSection.profile,
              onTap: selected == YonkeNavigationSection.profile
                  ? null
                  : () => context.go(
                      AppRoutes.yonkeProfile,
                      extra: isDemoSession,
                    ),
            ),
          ],
        ),
      ),
    ),
  );
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
                  ? const Color(0xFF114EB0)
                  : const Color(0xFF48515A),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
