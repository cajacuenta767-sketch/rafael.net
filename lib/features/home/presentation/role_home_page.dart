import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';

enum AppRole { client, yonke }

class RoleHomePage extends StatelessWidget {
  const RoleHomePage.client({super.key}) : role = AppRole.client;
  const RoleHomePage.yonke({super.key}) : role = AppRole.yonke;

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    if (role == AppRole.client) return const _ClientHomePage();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(AppConfig.enableMockAuth ? 'Yonke · Modo prueba' : 'Yonke'),
      ),
      body: const Center(child: Text('Inicio de yonke pendiente de diseño.')),
    );
  }
}

class _ClientHomePage extends StatefulWidget {
  const _ClientHomePage();

  @override
  State<_ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<_ClientHomePage> {
  final _searchController = TextEditingController();
  int _selectedTab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 380 ? 20 : 28,
                  18,
                  MediaQuery.sizeOf(context).width < 380 ? 20 : 28,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _HomeContent(searchController: _searchController),
                  ),
                ),
              ),
            ),
            _BottomNavigation(
              selectedIndex: _selectedTab,
              onSelected: (index) {
                if (index == 3) {
                  context.push(AppRoutes.clientRequests);
                  return;
                }
                setState(() => _selectedTab = index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: _HomeWordmark()),
        const SizedBox(height: 24),
        Text('Hola, cliente', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 30),
        Text(
          '¿Qué refacción buscas?',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Ej. Alternador Nissan',
            prefixIcon: const Icon(Icons.search, size: 21),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categorías',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => _showAllCategories(context, searchController),
              child: const Text('Ver todas ›'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _Categories(searchController: searchController),
        const SizedBox(height: 28),
        Text(
          'Mis solicitudes',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _RequestCard(onTap: () => context.push(AppRoutes.clientRequests)),
      ],
    );
  }
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'refaNet',
      child: ExcludeSemantics(
        child: Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'refa',
                style: TextStyle(color: Color(0xFF092B61)),
              ),
              TextSpan(
                text: 'Net',
                style: TextStyle(color: Color(0xFF14951F)),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            fontSize: 25,
          ),
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _categoryItems
          .take(4)
          .map(
            (item) => Expanded(
              child: Semantics(
                button: true,
                label: 'Categoría ${item.label}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectCategory(searchController, item.label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item.icon,
                            color: const Color(0xFF384049),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

typedef _Category = ({String label, IconData icon});

const _categoryItems = <_Category>[
  (label: 'Motor', icon: Icons.settings_outlined),
  (label: 'Transmisión', icon: Icons.album_outlined),
  (label: 'Frenos', icon: Icons.radio_button_checked_outlined),
  (label: 'Eléctrico', icon: Icons.electric_bolt_outlined),
  (label: 'Suspensión', icon: Icons.car_repair_outlined),
  (label: 'Dirección', icon: Icons.turn_slight_right_outlined),
  (label: 'Enfriamiento', icon: Icons.ac_unit_outlined),
  (label: 'Combustible', icon: Icons.local_gas_station_outlined),
  (label: 'Escape', icon: Icons.air_outlined),
  (label: 'Clutch', icon: Icons.settings_input_component_outlined),
  (label: 'Carrocería', icon: Icons.directions_car_outlined),
  (label: 'Iluminación', icon: Icons.lightbulb_outline),
  (label: 'Cristales', icon: Icons.window_outlined),
  (label: 'Interior', icon: Icons.event_seat_outlined),
  (label: 'Aire acondicionado', icon: Icons.air_outlined),
  (label: 'Llantas y rines', icon: Icons.tire_repair_outlined),
  (label: 'Seguridad', icon: Icons.health_and_safety_outlined),
  (label: 'Accesorios', icon: Icons.extension_outlined),
  (label: 'Herramientas', icon: Icons.handyman_outlined),
];

void _selectCategory(TextEditingController controller, String category) {
  controller.value = TextEditingValue(
    text: category,
    selection: TextSelection.collapsed(offset: category.length),
  );
}

void _showAllCategories(
  BuildContext context,
  TextEditingController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todas las categorías',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.15,
                ),
                itemCount: _categoryItems.length,
                itemBuilder: (context, index) {
                  final item = _categoryItems[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _selectCategory(controller, item.label);
                      Navigator.pop(sheetContext);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: const Color(0xFF384049)),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alternador Nissan\nSentra 2018',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Text('3 cotizaciones'),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.circle, size: 9, color: Color(0xFF14951F)),
                  SizedBox(width: 7),
                  Text('En proceso'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                icon: Icons.search,
                label: 'Buscar',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Crear solicitud',
                  child: Center(
                    child: InkWell(
                      onTap: () => context.push(AppRoutes.clientNewRequest),
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
              _NavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Solicitudes',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
  Widget build(BuildContext context) {
    return Expanded(
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
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
