import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/yonke_theme.dart';
import '../../../../core/di/api_providers.dart';

class YonkeDrawer extends ConsumerWidget {
  const YonkeDrawer({super.key, this.currentRoute = AppRoutes.yonkeRequests});

  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(color: YonkeColors.primaryNavy),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          YonkeAssets.icon,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.storefront,
                            size: 30,
                            color: YonkeColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yonke El Profe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFC107),
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '4.8 (120)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: YonkeColors.accentGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ACTIVO',
                                    style: TextStyle(
                                      color: YonkeColors.accentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'Panel Principal',
                    selected: currentRoute == AppRoutes.yonkeHome,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != AppRoutes.yonkeHome) {
                        context.go(AppRoutes.yonkeHome);
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox,
                    label: 'Solicitudes',
                    selected: currentRoute == AppRoutes.yonkeRequests,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != AppRoutes.yonkeRequests) {
                        context.go(AppRoutes.yonkeRequests);
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.request_quote_outlined,
                    selectedIcon: Icons.request_quote,
                    label: 'Cotizaciones',
                    selected: currentRoute == AppRoutes.yonkeQuotes,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != AppRoutes.yonkeQuotes) {
                        context.go(AppRoutes.yonkeQuotes);
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'Mensajes',
                    selected: currentRoute == AppRoutes.yonkeMessages,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != AppRoutes.yonkeMessages) {
                        context.go(AppRoutes.yonkeMessages);
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Mi Yonke / Perfil',
                    selected: currentRoute == AppRoutes.yonkeProfile,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != AppRoutes.yonkeProfile) {
                        context.go(AppRoutes.yonkeProfile);
                      }
                    },
                  ),
                  const Divider(height: 32),
                  _DrawerItem(
                    icon: Icons.store_outlined,
                    label: 'Modo Cliente',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.start);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: 'Ayuda y soporte',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(tokenStoreProvider).clear();
                  if (context.mounted) {
                    context.go(AppRoutes.yonkeLogin);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected
            ? YonkeColors.primaryNavy.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          selected ? (selectedIcon ?? icon) : icon,
          color: selected ? YonkeColors.primaryNavy : YonkeColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? YonkeColors.primaryNavy : YonkeColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
