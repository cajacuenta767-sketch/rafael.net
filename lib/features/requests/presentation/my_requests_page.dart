import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../domain/client_request.dart';

class MyRequestsPage extends ConsumerStatefulWidget {
  const MyRequestsPage({super.key});

  @override
  ConsumerState<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends ConsumerState<MyRequestsPage> {
  List<ClientRequestSummary> _requests = const [];
  bool _loading = true;
  String? _error;

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
    try {
      final response = await ref.read(dashboardApiProvider).getMyRequests();
      if (!mounted) return;
      setState(() {
        _requests = clientRequestSummariesFromResponse(response);
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
      bottomNavigationBar: const ClientBottomNavigation(currentIndex: 1),
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
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _RequestSummaryCard(request: _requests[index]),
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final ClientRequestSummary request;

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
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RefanetImage(
                    source: request.imageUrl,
                    fallback: const Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF14951F),
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (request.folio != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Folio ${request.folio}',
                          style: const TextStyle(color: Color(0xFF596276)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 18,
                            color: statusColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${request.quoteCount} cotizaciones',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.circle, size: 8, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            request.status,
                            style: TextStyle(color: statusColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
