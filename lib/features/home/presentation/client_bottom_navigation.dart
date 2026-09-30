import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/responsive.dart';

const _navy = Color(0xFF07284D);
const _green = Color(0xFF54B91B);
const _selected = Color(0xFF9BE63B);
const _idle = Color(0xFFB8C4D1);

/// Muestra [child] con la barra lateral del cliente en pantallas anchas
/// (tablet horizontal, laptop, monitor, TV). En celulares y tablets en
/// vertical devuelve [child] tal cual y la página usa la barra inferior.
class ClientNavigationFrame extends StatelessWidget {
  const ClientNavigationFrame({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.useSideNavigation(context)) return child;
    final extended = MediaQuery.sizeOf(context).width >= Breakpoints.large;
    return SideNavigationLayout(
      railWidth: extended ? 232 : 104,
      rail: _ClientSideNavigation(
        currentIndex: currentIndex,
        extended: extended,
      ),
      child: child,
    );
  }
}

class _ClientSideNavigation extends StatelessWidget {
  const _ClientSideNavigation({
    required this.currentIndex,
    required this.extended,
  });

  final int currentIndex;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final nav = ClientBottomNavigation(currentIndex: currentIndex);
    Widget item(int index, IconData icon, String label) => SideNavigationItem(
      icon: icon,
      label: label,
      selected: currentIndex == index,
      extended: extended,
      selectedColor: _selected,
      color: _idle,
      onTap: () => nav._select(context, index),
    );
    return Material(
      color: _navy,
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
                  label: 'Abrir acciones rápidas',
                  excludeSemantics: true,
                  child: Material(
                    color: _green,
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
                      onTap: () => nav._select(context, 2),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, color: Colors.white, size: 28),
                            if (extended) ...[
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Nueva solicitud',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
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
              item(0, Icons.home_outlined, 'Inicio'),
              item(1, Icons.assignment_outlined, 'Solicitudes'),
              item(3, Icons.chat_bubble_outline_rounded, 'Mensajes'),
              item(4, Icons.person_outline, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientBottomNavigation extends StatelessWidget {
  const ClientBottomNavigation({super.key, required this.currentIndex});

  final int currentIndex;

  Future<void> _showQuickActions(BuildContext context) async {
    // En pantallas anchas las acciones se abren como diálogo centrado.
    final action = Breakpoints.useSideNavigation(context)
        ? await showDialog<_ClientQuickAction>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const _QuickActionsSheet(),
              ),
            ),
          )
        : await showModalBottomSheet<_ClientQuickAction>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (sheetContext) => const _QuickActionsSheet(),
          );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _ClientQuickAction.newRequest:
        context.push(AppRoutes.clientNewRequest);
        return;
      case _ClientQuickAction.exploreYonkes:
        context.push(AppRoutes.clientYonkes);
        return;
    }
  }

  void _select(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.clientHome);
        return;
      case 1:
        context.go(AppRoutes.clientRequests);
        return;
      case 2:
        _showQuickActions(context);
        return;
      case 3:
        context.go(AppRoutes.clientMessages);
        return;
      case 4:
        context.go(AppRoutes.clientProfile);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Con la barra lateral visible la inferior no se muestra.
    if (SideNavigationScope.active(context)) {
      return const SizedBox.shrink();
    }
    return _buildBar(context);
  }

  Widget _buildBar(BuildContext context) => Material(
    color: const Color(0xFF07284D),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            _NavigationItem(
              icon: Icons.home_outlined,
              label: 'Inicio',
              selected: currentIndex == 0,
              onTap: () => _select(context, 0),
            ),
            _NavigationItem(
              icon: Icons.assignment_outlined,
              label: 'Solicitudes',
              selected: currentIndex == 1,
              onTap: () => _select(context, 1),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Abrir acciones rápidas',
                child: Center(
                  child: InkWell(
                    onTap: () => _select(context, 2),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFF54B91B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
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
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Mensajes',
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

enum _ClientQuickAction { newRequest, exploreYonkes }

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2607284D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8DDE3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '¿Qué deseas hacer?',
              style: TextStyle(
                color: Color(0xFF07284D),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _QuickActionTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'Nueva solicitud',
            subtitle: 'Publica la autoparte que necesitas',
            onTap: () => Navigator.pop(context, _ClientQuickAction.newRequest),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.storefront_outlined,
            title: 'Explorar yonkes',
            subtitle: 'Consulta yonkes, cobertura y opiniones',
            onTap: () =>
                Navigator.pop(context, _ClientQuickAction.exploreYonkes),
          ),
        ],
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F8F3),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2DA51E), size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF07284D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF737B85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2DA51E)),
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
                  ? const Color(0xFF9BE63B)
                  : const Color(0xFFB8C4D1),
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
                        ? const Color(0xFF9BE63B)
                        : const Color(0xFFB8C4D1),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
