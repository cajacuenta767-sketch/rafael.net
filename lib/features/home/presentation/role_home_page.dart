import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../requests/domain/client_request.dart';
import 'client_bottom_navigation.dart';

class RoleHomePage extends StatelessWidget {
  const RoleHomePage.client({super.key});

  @override
  Widget build(BuildContext context) => const _ClientHomePage();
}

class _ClientHomePage extends StatefulWidget {
  const _ClientHomePage();

  @override
  State<_ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<_ClientHomePage> {
  final _searchController = TextEditingController();

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
            const ClientBottomNavigation(currentIndex: 0),
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
          onSubmitted: (value) {
            final query = value.trim();
            if (query.isNotEmpty) {
              context.push(
                '${AppRoutes.clientSearch}?q=${Uri.encodeQueryComponent(query)}',
              );
            }
          },
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
        const _RecentRequestCard(),
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

/// Última solicitud del cliente, desde
/// `GET /api/DashboardSuscriptores/mi-solicitud-reciente`.
class _RecentRequestCard extends ConsumerStatefulWidget {
  const _RecentRequestCard();

  @override
  ConsumerState<_RecentRequestCard> createState() => _RecentRequestCardState();
}

class _RecentRequestCardState extends ConsumerState<_RecentRequestCard> {
  ClientRequestSummary? _request;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await ref.read(dashboardApiProvider).getRecentRequest();
      if (!mounted) return;
      setState(() {
        _request = clientRequestSummaryFromResponse(response);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        key: const Key('home-recent-request'),
        borderRadius: BorderRadius.circular(14),
        onTap: request == null
            ? () => context.push(AppRoutes.clientRequests)
            : () => context.push(AppRoutes.clientRequestDetail(request.id)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _loading
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _failed
              ? _RecentRequestMessage(
                  text: 'No pudimos consultar tu última solicitud.',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : request == null
              ? _RecentRequestMessage(
                  text: 'Aún no tienes solicitudes.',
                  actionLabel: 'Crear solicitud',
                  onAction: () => context.push(AppRoutes.clientNewRequest),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text('${request.quoteCount} cotizaciones'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: request.isInProgress
                              ? const Color(0xFF14951F)
                              : const Color(0xFF596276),
                        ),
                        const SizedBox(width: 7),
                        Text(request.status),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RecentRequestMessage extends StatelessWidget {
  const _RecentRequestMessage({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(text, style: const TextStyle(color: Color(0xFF596276))),
      ),
      TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}
