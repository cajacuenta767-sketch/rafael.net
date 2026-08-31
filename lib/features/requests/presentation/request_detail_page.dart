import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';

class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  _RequestDetail? _detail;
  bool _loading = true;
  bool _usingTestData = false;
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

    if (AppConfig.enableMockAuth) {
      setState(() {
        _detail = _mockRequestDetail(widget.requestId);
        _usingTestData = true;
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        ref.read(requestsApiProvider).getById(widget.requestId),
        ref.read(requestsApiProvider).getImages(widget.requestId),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = _requestDetailFromResponses(results[0], results[1]);
        _usingTestData = false;
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
          if (_usingTestData) ...[
            const _TestDetailNotice(),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.part,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 18),
          _DetailCard(
            title: 'Información de la pieza',
            children: [
              _DetailRow(label: 'Marca', value: detail.brand),
              _DetailRow(label: 'Modelo', value: detail.model),
              _DetailRow(label: 'Año', value: detail.year),
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
                    if (imageUrl.startsWith('mock://')) {
                      return const _MockPhoto();
                    }
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
                      '${detail.quoteCount} cotizaciones',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: detail.quoteCount > 0
                    ? () => context.push(
                        AppRoutes.clientRequestQuotes(widget.requestId),
                        extra:
                            '${detail.part} ${detail.brand} ${detail.model} ${detail.year}',
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

class _TestDetailNotice extends StatelessWidget {
  const _TestDetailNotice();

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
          child: Text('Detalle de prueba; todavía no proviene de la API.'),
        ),
      ],
    ),
  );
}

class _MockPhoto extends StatelessWidget {
  const _MockPhoto();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFE9ECEF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Icon(
        Icons.car_repair_outlined,
        size: 44,
        color: Color(0xFF596276),
      ),
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

class _RequestDetail {
  const _RequestDetail({
    required this.part,
    required this.brand,
    required this.model,
    required this.year,
    required this.city,
    required this.status,
    required this.quoteCount,
    required this.imageUrls,
    this.description,
  });

  final String part;
  final String brand;
  final String model;
  final String year;
  final String city;
  final String status;
  final int quoteCount;
  final List<String> imageUrls;
  final String? description;
}

_RequestDetail? _requestDetailFromResponses(
  dynamic requestResponse,
  dynamic imagesResponse,
) {
  final raw = requestResponse is Map
      ? requestResponse['data'] ?? requestResponse
      : null;
  if (raw is! Map) return null;

  final imagesData = imagesResponse is Map
      ? imagesResponse['data']
      : imagesResponse;
  final imageRecords = imagesData is List ? imagesData : const <dynamic>[];
  final imageUrls = imageRecords
      .whereType<Map>()
      .map(
        (image) =>
            image['url']?.toString() ??
            image['imagenUrl']?.toString() ??
            image['ruta']?.toString(),
      )
      .whereType<String>()
      .where((url) => url.startsWith('https://'))
      .toList();

  return _RequestDetail(
    part: raw['piezaBuscada']?.toString() ?? 'Pieza sin nombre',
    brand: raw['marca']?.toString() ?? 'Sin información',
    model: raw['modelo']?.toString() ?? 'Sin información',
    year: raw['año']?.toString() ?? 'Sin información',
    description: raw['descripcion']?.toString(),
    city: raw['ciudad']?.toString() ?? 'Sin información',
    status: raw['estatus']?.toString() ?? 'Sin estado',
    quoteCount: (raw['cotizaciones'] as num?)?.toInt() ?? 0,
    imageUrls: imageUrls,
  );
}

_RequestDetail? _mockRequestDetail(String requestId) {
  if (requestId == 'mock-request-faro') {
    return const _RequestDetail(
      part: 'Faro delantero',
      brand: 'Toyota',
      model: 'Corolla',
      year: '2016',
      city: 'Hermosillo, Sonora',
      status: 'En proceso',
      quoteCount: 1,
      imageUrls: ['mock://faro'],
      description: 'Faro delantero derecho en buen estado.',
    );
  }
  if (requestId == 'mock-request-alternador') {
    return const _RequestDetail(
      part: 'Alternador',
      brand: 'Nissan',
      model: 'Sentra',
      year: '2018',
      city: 'Nogales, Sonora',
      status: 'En proceso',
      quoteCount: 3,
      imageUrls: [
        'mock://alternador-1',
        'mock://alternador-2',
        'mock://alternador-3',
      ],
      description: 'Original o compatible en buen estado.',
    );
  }
  return null;
}
