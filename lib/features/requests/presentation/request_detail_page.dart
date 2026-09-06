import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../domain/client_request.dart';

class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  ClientRequestDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(requestsApiProvider);
      final results = await Future.wait<dynamic>([
        api.getById(widget.requestId),
        // Fotos y ciudades son complementarias: si fallan, el detalle se
        // muestra igual.
        _optional(api.getImages(widget.requestId)),
        _optional(api.getCities(widget.requestId)),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = clientRequestDetailFromResponses(
          requestResponse: results[0],
          imagesResponse: results[1],
          citiesResponse: results[2],
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar esta solicitud. Inténtalo nuevamente.';
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
        title: const Text('Detalle de solicitud'),
        actions: [
          IconButton(
            tooltip: 'Actualizar detalle',
            onPressed: _loading ? null : _loadDetail,
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
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _DetailMessage(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar la solicitud',
        message: _error!,
        onRetry: _loadDetail,
      );
    }

    final detail = _detail;
    if (detail == null) {
      return _DetailMessage(
        icon: Icons.search_off_outlined,
        title: 'Solicitud no encontrada',
        message: 'La solicitud solicitada no está disponible.',
        onRetry: _loadDetail,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.summary.part,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(status: detail.summary.status),
            ],
          ),
          const SizedBox(height: 18),
          _DetailCard(
            title: 'Información de la pieza',
            children: [
              _DetailRow(
                label: 'Marca',
                value: detail.summary.brand ?? 'Sin información',
              ),
              _DetailRow(
                label: 'Modelo',
                value: detail.summary.model ?? 'Sin información',
              ),
              _DetailRow(
                label: 'Año',
                value: detail.summary.year?.toString() ?? 'Sin información',
              ),
              if (detail.engine != null)
                _DetailRow(label: 'Motor', value: detail.engine!),
              if (detail.transmission != null)
                _DetailRow(label: 'Transmisión', value: detail.transmission!),
              if (detail.partNumber != null)
                _DetailRow(label: 'No. de parte', value: detail.partNumber!),
              if (detail.description != null)
                _DetailRow(label: 'Descripción', value: detail.description!),
            ],
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Ubicación',
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(detail.city)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Fotografías (${detail.imageUrls.length})',
            children: [
              if (detail.imageUrls.isEmpty)
                const Text(
                  'Esta solicitud no tiene fotografías disponibles.',
                  style: TextStyle(color: Color(0xFF596276)),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: detail.imageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = detail.imageUrls[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ImageError(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Cotizaciones recibidas',
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    color: Color(0xFF14951F),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${detail.summary.quoteCount} cotizaciones',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: detail.summary.quoteCount > 0
                    ? () => context.push(
                        AppRoutes.clientRequestQuotes(widget.requestId),
                        extra: detail.summary.title.replaceAll('\n', ' '),
                      )
                    : null,
                child: const Text('Ver cotizaciones'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5EA),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: Color(0xFF147A1D),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: Color(0xFF596276))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE9ECEF),
    child: const Center(child: Icon(Icons.broken_image_outlined)),
  );
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
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
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

Future<dynamic> _optional(Future<dynamic> request) async {
  try {
    return await request;
  } catch (_) {
    return null;
  }
}
