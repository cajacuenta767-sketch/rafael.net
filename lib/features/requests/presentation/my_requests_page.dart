import '../../../app/widgets/responsive_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/status_colors.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
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
    final memory = ref.read(clientRequestsMemoryProvider);
    String? email;
    try {
      final profileSnapshot =
          await ref.read(clientProfileRepositoryProvider).load();
      email = profileSnapshot.profile.email;
    } catch (_) {}

    final cached = await memory.loadRequests(email);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _requests = cached;
        _loading = false;
        _error = null;
      });
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response =
          await ref.read(dashboardApiProvider).getMyRequests(pageSize: 50);
      var list = clientRequestSummariesFromResponse(response);
      if (list.isEmpty) {
        try {
          final recentResponse = await ref
              .read(dashboardApiProvider)
              .getRecentRequest();
          final recent = clientRequestSummaryFromResponse(recentResponse);
          if (recent != null) {
            list = [recent];
          }
        } catch (_) {}
      }

      await memory.saveRequests(email, list);
      final merged = await memory.loadRequests(email);

      if (!mounted) return;
      setState(() {
        _requests = merged.isNotEmpty
            ? merged
            : (_requests.isNotEmpty ? _requests : list);
        _loading = false;
      });
      if (_requests.isNotEmpty &&
          _requests.any((r) => r.imageUrl == null || r.imageUrl!.isEmpty)) {
        _hydrateImages(_requests, email);
      }
    } catch (error) {
      if (!mounted) return;
      if (_requests.isNotEmpty) {
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = error is ApiException
              ? error.message
              : 'No se pudieron cargar tus solicitudes. Inténtalo nuevamente.';
        });
      }
    }
  }

  void _hydrateImages(
    List<ClientRequestSummary> initial, [
    String? email,
  ]) async {
    final requestsApi = ref.read(requestsApiProvider);
    var updated = false;
    final updatedList = await Future.wait(
      initial.map((req) async {
        if (req.imageUrl != null && req.imageUrl!.isNotEmpty) return req;
        try {
          final imagesResponse = await requestsApi.getImages(req.id);
          final urls = requestImageUrlsFromResponse(imagesResponse);
          if (urls.isNotEmpty) {
            updated = true;
            return req.copyWith(imageUrl: urls.first);
          }
          return req;
        } catch (_) {
          return req;
        }
      }),
    );
    if (updated && mounted) {
      setState(() {
        _requests = updatedList;
      });
      ref.read(clientRequestsMemoryProvider).saveRequests(email, updatedList);
    }
  }

  Future<void> _cancelRequest(ClientRequestSummary request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar solicitud?'),
        content: Text(
          '¿Deseas cancelar la solicitud "${request.title}"? Esta acción se enviará al servidor y liberará espacio en tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirm-delete-request-button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(requestsApiProvider)
          .cancel(requestId: request.id, notes: 'Cancelada por el cliente');
      await ref
          .read(clientRequestsMemoryProvider)
          .markRequestCancelled(null, request.id);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudo cancelar la solicitud. Inténtalo nuevamente.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Solicitud cancelada correctamente.')),
    );
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
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
        itemBuilder: (context, index) => _RequestSummaryCard(
          request: _requests[index],
          onCancel: () => _cancelRequest(_requests[index]),
          onReload: _loadRequests,
        ),
      ),
    );
  }
}

Color _clientRequestStatusColor(String status) => AppStatusColors.fromStatus(status);

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({
    required this.request,
    this.onCancel,
    this.onReload,
  });

  final ClientRequestSummary request;
  final VoidCallback? onCancel;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final statusColor = _clientRequestStatusColor(request.status);
    return Semantics(
      button: true,
      label: 'Solicitud ${request.title}, ${request.status}',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await context.push(
              AppRoutes.clientRequestDetail(request.id),
            );
            if (result == true) {
              onReload?.call();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: AdaptiveInline(
              minimumInlineWidth: 200,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${request.quoteCount} cotizaciones',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              request.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onCancel != null && request.isInProgress) ...[
                            IconButton(
                              key: Key('cancel-request-card-${request.id}'),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFB3261E),
                                size: 20,
                              ),
                              tooltip: 'Cancelar solicitud',
                              onPressed: onCancel,
                            ),
                          ],
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
