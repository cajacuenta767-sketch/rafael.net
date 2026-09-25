import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../quotes/domain/client_quote.dart';
import '../domain/client_request.dart';
import '../data/requests_api.dart';

const _navy = Color(0xFF072C4F);
const _greenDark = Color(0xFF26971F);
const _muted = Color(0xFF7F8790);
const _line = Color(0xFFE9ECEF);

class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  ClientRequestDetail? _detail;
  List<ClientQuote> _quotes = const [];
  bool _loading = true;
  bool _cancelling = false;
  bool _deletingPhoto = false;
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
      final requests = ref.read(requestsApiProvider);
      final results = await Future.wait<dynamic>([
        clientRequestResponse(
          requests,
          ref.read(dashboardApiProvider),
          widget.requestId,
        ),
        _optional(requests.getImages(widget.requestId)),
        _optional(requests.getCities(widget.requestId)),
        _optional(ref.read(dashboardApiProvider).getMyQuotes()),
      ]);
      final detail = clientRequestDetailFromResponses(
        requestResponse: results[0],
        imagesResponse: results[1],
        citiesResponse: results[2],
      );
      if (!mounted) return;

      final quotes = detail == null
          ? <ClientQuote>[]
          : await ref
                .read(quoteYonkeResolverProvider)
                .resolveAll(
                  clientQuotesFromDashboard(results[3])
                      .where((quote) {
                        if (quote.requestId.isNotEmpty) {
                          return quote.requestId == widget.requestId;
                        }
                        return quote.requestFolio != null &&
                            quote.requestFolio == detail.summary.folio;
                      })
                      .toList(growable: false),
                );
      if (!mounted) return;

      setState(() {
        _detail = detail;
        _quotes = quotes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'No se pudo cargar esta solicitud. Inténtalo nuevamente.';
      });
    }
  }

  Future<void> _deletePhoto(String imageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta foto?'),
        content: const Text('Los yonkes dejarán de verla en tu solicitud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-request-photo-delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingPhoto = true);
    try {
      await ref.read(requestsApiProvider).deleteImage(imageId);
      if (mounted) await _loadDetail();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la foto. Inténtalo nuevamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingPhoto = false);
    }
  }

  Future<void> _share() async {
    final detail = _detail;
    if (detail == null) return;
    final summary = detail.summary;
    final text = [
      'Solicitud ${summary.folio ?? summary.id}',
      summary.part,
      if (summary.vehicle.isNotEmpty) summary.vehicle,
      if (detail.description != null) detail.description!,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud copiada para compartir.')),
      );
    }
  }

  Future<void> _cancelRequest() async {
    if (_cancelling) return;
    String? noteText;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final notes = TextEditingController();
        return AlertDialog(
          title: const Text('¿Cancelar solicitud?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Los yonkes dejarán de recibir este pedido. Esta acción no se puede deshacer.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Por ejemplo: ya encontré la pieza',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              key: const Key('confirm-cancel-request'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
              ),
              onPressed: () {
                noteText = notes.text.trim();
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(requestsApiProvider)
          .cancel(
            requestId: widget.requestId,
            notes: (noteText?.isEmpty ?? true) ? null : noteText,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _cancelling = false);
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

    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.clientRequests);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Regresar',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_new, color: _navy, size: 18),
      ),
      title: const Text(
        'Detalle de solicitud',
        style: TextStyle(
          color: _navy,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          color: Colors.white,
          icon: const Icon(Icons.more_vert, color: _navy),
          onSelected: (value) {
            if (value == 'refresh') _loadDetail();
            if (value == 'cancel') _cancelRequest();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'refresh', child: Text('Actualizar')),
            if (_detail != null && !_detail!.summary.closed)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB3261E),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cancelar solicitud',
                      style: TextStyle(color: Color(0xFFB3261E)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _body(),
        ),
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _greenDark));
    }
    if (_error != null) {
      return _DetailMessage(message: _error!, onRetry: _loadDetail);
    }
    final detail = _detail;
    if (detail == null) {
      return _DetailMessage(
        message: 'La solicitud no está disponible.',
        onRetry: _loadDetail,
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: _greenDark,
            onRefresh: _loadDetail,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              children: [
                _RequestMeta(detail: detail),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: _line),
                ),
                _RequestSummary(detail: detail),
                const SizedBox(height: 18),
                _PhotosSection(
                  imageUrls: detail.imageUrls,
                  onDelete: detail.summary.closed || _deletingPhoto
                      ? null
                      : (url) {
                          final id = detail.imageIds[url];
                          if (id != null) _deletePhoto(id);
                        },
                  canDelete: (url) => detail.imageIds.containsKey(url),
                ),
                const SizedBox(height: 20),
                const _DispatchSection(),
                const SizedBox(height: 20),
                _QuotesSection(
                  quotes: _quotes,
                  expectedCount: detail.summary.quoteCount,
                  requestId: widget.requestId,
                  requestTitle: detail.summary.title.replaceAll('\n', ' '),
                  requestFolio: detail.summary.folio,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _BottomActions(
          canCancel: !detail.summary.closed && !_cancelling,
          onCancel: _cancelRequest,
          onShare: _share,
        ),
      ],
    );
  }
}

class _RequestMeta extends StatelessWidget {
  const _RequestMeta({required this.detail});
  final ClientRequestDetail detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _StatusChip(status: detail.summary.status),
      const Spacer(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Solicitud ${detail.summary.folio ?? detail.summary.id}',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          if (detail.summary.createdAt != null)
            Text(
              _date(detail.summary.createdAt!),
              style: const TextStyle(color: Color(0xFFA0A6AC), fontSize: 9),
            ),
        ],
      ),
    ],
  );
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.detail});
  final ClientRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail.imageUrls.firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequestImage(url: imageUrl, size: 86),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.summary.part,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail.summary.vehicle.isEmpty
                    ? 'Vehículo sin información'
                    : detail.summary.vehicle,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail.partNumber != null) ...[
                const SizedBox(height: 2),
                Text(
                  'No. de parte: ${detail.partNumber}',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
              if (detail.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail.description!,
                  style: const TextStyle(
                    color: Color(0xFF4D555D),
                    fontSize: 11,
                  ),
                ),
              ],
              if (detail.cities.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: _greenDark,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        detail.city,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.imageUrls,
    this.onDelete,
    this.canDelete,
  });
  final List<String> imageUrls;
  final ValueChanged<String>? onDelete;
  final bool Function(String url)? canDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: 'Fotos',
        action: imageUrls.isEmpty
            ? '0 disponibles'
            : '${imageUrls.length} disponibles',
      ),
      const SizedBox(height: 9),
      if (imageUrls.isEmpty)
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F7),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _line),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_outlined, color: _muted, size: 21),
              SizedBox(width: 8),
              Text(
                'Esta solicitud no tiene fotos',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        )
      else
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, index) {
              final url = imageUrls[index];
              final image = _RequestImage(url: url, size: 82);
              if (onDelete == null || canDelete?.call(url) != true) {
                return image;
              }
              return Stack(
                children: [
                  image,
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: Key('request-photo-delete-$index'),
                        customBorder: const CircleBorder(),
                        onTap: () => onDelete!(url),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    ],
  );
}

class _DispatchSection extends StatelessWidget {
  const _DispatchSection();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeader(title: 'Enviada a yonkes con cobertura', action: ''),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FBF3),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE2F4D9),
              child: Icon(Icons.send_outlined, color: _greenDark, size: 19),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'La lista de destinatarios no está disponible en el API.',
                style: TextStyle(color: Color(0xFF56605A), fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _QuotesSection extends StatelessWidget {
  const _QuotesSection({
    required this.quotes,
    required this.expectedCount,
    required this.requestId,
    required this.requestTitle,
    required this.requestFolio,
  });
  final List<ClientQuote> quotes;
  final int expectedCount;
  final String requestId;
  final String requestTitle;
  final String? requestFolio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: 'Cotizaciones recibidas',
        action:
            '$expectedCount ${expectedCount == 1 ? 'cotización' : 'cotizaciones'}',
      ),
      const SizedBox(height: 9),
      if (quotes.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            expectedCount > 0
                ? 'El API reporta $expectedCount, pero no entregó sus datos completos.'
                : 'Aún no hay cotizaciones para esta solicitud.',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var index = 0; index < quotes.length; index++) ...[
                _QuoteRow(quote: quotes[index]),
                if (index < quotes.length - 1)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: _line,
                  ),
              ],
            ],
          ),
        ),
      if (quotes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: _greenDark),
            onPressed: () => context.push(
              AppRoutes.clientRequestQuotes(requestId),
              extra: {'title': requestTitle, 'folio': requestFolio},
            ),
            child: const Text('Ver todas'),
          ),
        ),
      ],
    ],
  );
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.quote});
  final ClientQuote quote;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _price(quote.price),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                quote.yonkeName,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${quote.condition} · ${quote.availability}',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: () =>
              context.push(AppRoutes.clientQuoteDetail(quote.id), extra: quote),
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 36),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: const StadiumBorder(),
          ),
          child: const Text(
            'Ver',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (action.isNotEmpty)
        Text(
          action,
          style: const TextStyle(
            color: _greenDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _RequestImage extends StatelessWidget {
  const _RequestImage({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFFEAF6E5),
      child: url == null
          ? const Icon(
              Icons.directions_car_outlined,
              color: _greenDark,
              size: 34,
            )
          : RefanetImage(
              source: url,
              fit: BoxFit.cover,
              fallback: const Icon(Icons.broken_image_outlined, color: _muted),
            ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF79D631), _greenDark]),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.canCancel,
    required this.onCancel,
    required this.onShare,
  });
  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: canCancel ? onCancel : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: _line),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Cancelar solicitud',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF72D22D), _greenDark],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('share-request-button'),
                onTap: onShare,
                borderRadius: BorderRadius.circular(25),
                child: const SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'Compartir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 50, color: _muted),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
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

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · ${two(value.hour)}:${two(value.minute)}';
}

String _price(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '\$$buffer';
}
