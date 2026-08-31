import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';

class MyRequestsPage extends ConsumerStatefulWidget {
  const MyRequestsPage({super.key});

  @override
  ConsumerState<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends ConsumerState<MyRequestsPage> {
  List<_RequestSummary> _requests = const [];
  bool _loading = true;
  String? _error;
  bool _usingTestData = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (AppConfig.enableMockAuth) {
      setState(() {
        _requests = _testRequests;
        _usingTestData = true;
        _loading = false;
      });
      return;
    }

    try {
      final response = await ref.read(dashboardApiProvider).getMyRequests();
      if (!mounted) return;
      setState(() {
        _requests = _requestSummariesFromResponse(response);
        _usingTestData = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar tus solicitudes. Inténtalo nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCFC),
        surfaceTintColor: const Color(0xFFFCFCFC),
        centerTitle: true,
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar solicitudes',
            onPressed: _loading ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildBody(context),
          ),
        ),
      ),
      bottomNavigationBar: const ClientBottomNavigation(currentIndex: 3),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar tus solicitudes',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _loadRequests,
      );
    }

    if (_requests.isEmpty) {
      return _MessageState(
        icon: Icons.receipt_long_outlined,
        title: 'Aún no tienes solicitudes',
        message: 'Crea una solicitud para recibir cotizaciones de los yonkes.',
        actionLabel: 'Actualizar',
        onAction: _loadRequests,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        itemCount: _requests.length + (_usingTestData ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_usingTestData && index == 0) {
            return const _TestDataNotice();
          }
          final request = _requests[index - (_usingTestData ? 1 : 0)];
          return _RequestSummaryCard(request: request);
        },
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final _RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final statusColor = request.isInProgress
        ? const Color(0xFF14951F)
        : const Color(0xFF596276);
    return Semantics(
      button: true,
      label: 'Solicitud ${request.title}, ${request.status}',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.clientRequestDetail(request.id)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (request.city != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 17),
                      const SizedBox(width: 5),
                      Expanded(child: Text(request.city!)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${request.quoteCount} cotizaciones',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Icon(Icons.circle, size: 9, color: statusColor),
                    const SizedBox(width: 6),
                    Text(request.status, style: TextStyle(color: statusColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TestDataNotice extends StatelessWidget {
  const _TestDataNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF8F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Color(0xFF147A1D)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Solicitudes de prueba. Se reemplazarán por tus datos al completar el inicio de sesión real.',
          ),
        ),
      ],
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: const Color(0xFF596276)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

class _RequestSummary {
  const _RequestSummary({
    required this.id,
    required this.title,
    required this.quoteCount,
    required this.status,
    this.city,
  });

  final String id;
  final String title;
  final int quoteCount;
  final String status;
  final String? city;

  bool get isInProgress => status.toLowerCase() == 'en proceso';
}

List<_RequestSummary> _requestSummariesFromResponse(dynamic response) {
  final data = response is Map ? response['data'] : response;
  final records = switch (data) {
    List() => data,
    Map() when data['items'] is List => data['items'] as List,
    Map() when data['registros'] is List => data['registros'] as List,
    _ => const <dynamic>[],
  };

  return records
      .whereType<Map>()
      .map((record) {
        final title = record['piezaBuscada']?.toString();
        final brand = record['marca']?.toString();
        final model = record['modelo']?.toString();
        final vehicle = [
          brand,
          model,
        ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
        return _RequestSummary(
          id: record['guidId']?.toString() ?? record['id']?.toString() ?? '',
          title: [
            title,
            vehicle,
          ].whereType<String>().where((value) => value.isNotEmpty).join('\n'),
          quoteCount: (record['cotizaciones'] as num?)?.toInt() ?? 0,
          status: record['estatus']?.toString() ?? 'Sin estado',
          city: record['ciudad']?.toString(),
        );
      })
      .where((request) => request.id.isNotEmpty && request.title.isNotEmpty)
      .toList();
}

const _testRequests = [
  _RequestSummary(
    id: 'mock-request-alternador',
    title: 'Alternador\nNissan Sentra 2018',
    quoteCount: 3,
    status: 'En proceso',
    city: 'Nogales, Sonora',
  ),
  _RequestSummary(
    id: 'mock-request-faro',
    title: 'Faro delantero\nToyota Corolla 2016',
    quoteCount: 1,
    status: 'En proceso',
    city: 'Hermosillo, Sonora',
  ),
];
