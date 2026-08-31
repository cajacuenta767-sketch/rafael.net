import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../data/yonke_request_detail_repository.dart';
import '../domain/yonke_request_detail.dart';
import '../domain/yonke_request_summary.dart';
import 'yonke_quote_page.dart';

class YonkeRequestDetailPage extends ConsumerStatefulWidget {
  const YonkeRequestDetailPage({
    super.key,
    required this.requestYonkeId,
    this.request,
    this.repository,
  });

  final String requestYonkeId;
  final YonkeRequestSummary? request;
  final YonkeRequestDetailRepository? repository;

  @override
  ConsumerState<YonkeRequestDetailPage> createState() =>
      _YonkeRequestDetailPageState();
}

class _YonkeRequestDetailPageState
    extends ConsumerState<YonkeRequestDetailPage> {
  late YonkeRequestDetailRepository _repository;
  YonkeRequestDetail? _detail;
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.request?.isDemo == true
            ? const DemoYonkeRequestDetailRepository()
            : ref.read(yonkeRequestDetailRepositoryProvider));
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await _repository.getDetail(
        requestId: widget.request?.requestId ?? '',
        requestYonkeId: widget.requestYonkeId,
        summary: widget.request,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _markUnavailable() async {
    final detail = _detail;
    if (detail == null || _submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Marcar como no disponible?'),
        content: const Text(
          'El cliente recibirá que este yonke no tiene disponible la pieza. Esta acción no debe usarse si deseas enviar un precio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-unavailable-button'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _repository.markUnavailable(detail.requestYonkeId);
      if (!mounted) return;
      setState(() {
        _detail = detail.copyWith(status: YonkeRequestStatus.unavailable);
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.isDemo
                ? 'Respuesta de prueba guardada. No se envió a la API.'
                : 'La solicitud se marcó como no disponible.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo enviar la respuesta. Inténtalo nuevamente.',
          ),
        ),
      );
    }
  }

  void _openQuote(YonkeRequestDetail detail) {
    context.push(
      AppRoutes.yonkeNewQuote(detail.requestYonkeId),
      extra: YonkeQuotePageArgs(detail: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFBFD),
        surfaceTintColor: const Color(0xFFFAFBFD),
        centerTitle: true,
        title: const Text('Detalle de solicitud'),
        actions: [
          IconButton(
            tooltip: 'Actualizar detalle',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: detail?.canRespond == true
          ? _ResponseActions(
              submitting: _submitting,
              onUnavailable: _markUnavailable,
              onQuote: () => _openQuote(detail!),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      final notFound = _error is YonkeRequestDetailNotFoundException;
      return _DetailState(
        icon: notFound ? Icons.search_off : Icons.cloud_off_outlined,
        title: notFound
            ? 'Solicitud no disponible'
            : 'No pudimos cargar la solicitud',
        message: notFound
            ? 'Abre la solicitud desde la bandeja para conservar su identificador y sus datos.'
            : 'Comprueba tu conexión e inténtalo nuevamente.',
        onRetry: _load,
      );
    }
    final detail = _detail;
    if (detail == null) {
      return _DetailState(
        icon: Icons.search_off,
        title: 'Solicitud no encontrada',
        message: 'No existe información para mostrar.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
          12,
          MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
          28,
        ),
        children: [
          if (detail.isDemo) ...[
            const _DemoNotice(),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.part,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (detail.vehicle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        detail.vehicle,
                        style: const TextStyle(color: Color(0xFF596276)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Información de la pieza',
            icon: Icons.settings_outlined,
            children: [
              if (_hasText(detail.folio))
                _InfoRow(label: 'Folio', value: detail.folio!),
              if (_hasText(detail.brand))
                _InfoRow(label: 'Marca', value: detail.brand!),
              if (_hasText(detail.model))
                _InfoRow(label: 'Modelo', value: detail.model!),
              if (detail.year != null)
                _InfoRow(label: 'Año', value: detail.year.toString()),
              if (_hasText(detail.engine))
                _InfoRow(label: 'Motor', value: detail.engine!),
              if (_hasText(detail.transmission))
                _InfoRow(label: 'Transmisión', value: detail.transmission!),
              if (_hasText(detail.partNumber))
                _InfoRow(label: 'Núm. de parte', value: detail.partNumber!),
              if (_hasText(detail.description)) ...[
                const Divider(height: 24),
                const Text(
                  'Descripción del cliente',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(detail.description!),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Ubicación y recepción',
            icon: Icons.location_on_outlined,
            children: [
              _InfoRow(
                label: 'Ciudad',
                value: _hasText(detail.city)
                    ? detail.city!
                    : 'No incluida por la API',
              ),
              if (detail.receivedAt != null)
                _InfoRow(
                  label: 'Recibida',
                  value: _formatDate(detail.receivedAt!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Fotografías (${detail.imageUrls.length})',
            icon: Icons.photo_library_outlined,
            children: [
              if (detail.imageUrls.isEmpty)
                const Text(
                  'El cliente no agregó fotografías a esta solicitud.',
                  style: TextStyle(color: Color(0xFF596276)),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 540 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: detail.imageUrls.length,
                      itemBuilder: (context, index) => _RequestPhoto(
                        url: detail.imageUrls[index],
                        index: index,
                        onTap: () => _showPhoto(detail.imageUrls[index], index),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (!detail.canRespond) ...[
            const SizedBox(height: 14),
            _AnsweredNotice(status: detail.status),
          ],
        ],
      ),
    );
  }

  void _showPhoto(String url, int index) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: url.startsWith('demo://')
                        ? const _DemoPhoto(large: true)
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _ImageError(),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: 'Cerrar fotografía',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Text(
                  'Fotografía ${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseActions extends StatelessWidget {
  const _ResponseActions({
    required this.submitting,
    required this.onUnavailable,
    required this.onQuote,
  });

  final bool submitting;
  final VoidCallback onUnavailable;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 12,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('yonke-unavailable-button'),
                    onPressed: submitting ? null : onUnavailable,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const FittedBox(child: Text('No disponible')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('yonke-quote-button'),
                    onPressed: submitting ? null : onQuote,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF14951F),
                    ),
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Cotizar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE4E8EE)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF147A1D)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 106,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final YonkeRequestStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: _statusColor(status).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: _statusColor(status),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _RequestPhoto extends StatelessWidget {
  const _RequestPhoto({
    required this.url,
    required this.index,
    required this.onTap,
  });

  final String url;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Abrir fotografía ${index + 1}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url.startsWith('demo://')
            ? const _DemoPhoto()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => const _ImageError(),
              ),
      ),
    ),
  );
}

class _DemoPhoto extends StatelessWidget {
  const _DemoPhoto({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    constraints: large
        ? const BoxConstraints(minWidth: 280, minHeight: 280)
        : null,
    color: const Color(0xFFE9ECEF),
    child: Center(
      child: Icon(
        Icons.car_repair_outlined,
        size: large ? 96 : 46,
        color: const Color(0xFF596276),
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

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, color: Color(0xFF8A5A00)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Solicitud de prueba. Sus respuestas no se enviarán al servidor.',
          ),
        ),
      ],
    ),
  );
}

class _AnsweredNotice extends StatelessWidget {
  const _AnsweredNotice({required this.status});

  final YonkeRequestStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF4FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF114EB0)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            status == YonkeRequestStatus.unavailable
                ? 'Ya respondiste que esta pieza no está disponible.'
                : 'Esta solicitud ya fue respondida o cerrada.',
          ),
        ),
      ],
    ),
  );
}

class _DetailState extends StatelessWidget {
  const _DetailState({
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFF596276)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

Color _statusColor(YonkeRequestStatus status) => switch (status) {
  YonkeRequestStatus.newRequest => const Color(0xFF147A1D),
  YonkeRequestStatus.viewed => const Color(0xFF114EB0),
  YonkeRequestStatus.quoted => const Color(0xFF6D3BB6),
  YonkeRequestStatus.unavailable => const Color(0xFF9B1C1C),
  YonkeRequestStatus.closed => const Color(0xFF596276),
  YonkeRequestStatus.unknown => const Color(0xFF596276),
};
