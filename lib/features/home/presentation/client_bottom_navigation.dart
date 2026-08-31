import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

class ClientBottomNavigation extends StatelessWidget {
  const ClientBottomNavigation({super.key, required this.currentIndex});

  final int currentIndex;

  void _select(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.clientHome);
        return;
      case 1:
        context.go(AppRoutes.clientSearch);
        return;
      case 2:
        context.push(AppRoutes.clientNewRequest);
        return;
      case 3:
        context.go(AppRoutes.clientRequests);
        return;
      case 4:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El perfil del cliente será el siguiente módulo.'),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            _NavigationItem(
              icon: Icons.home_outlined,
              label: 'Inicio',
              selected: currentIndex == 0,
              onTap: () => _select(context, 0),
            ),
            _NavigationItem(
              icon: Icons.search,
              label: 'Buscar',
              selected: currentIndex == 1,
              onTap: () => _select(context, 1),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Crear solicitud',
                child: Center(
                  child: InkWell(
                    onTap: () => _select(context, 2),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00695C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _NavigationItem(
              icon: Icons.receipt_long_outlined,
              label: 'Solicitudes',
              selected: currentIndex == 3,
              onTap: () => _select(context, 3),
            ),
            _NavigationItem(
              icon: Icons.person_outline,
              label: 'Perfil',
              selected: currentIndex == 4,
              onTap: () => _select(context, 4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(0xFF00695C)
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
