import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/api_providers.dart';
import '../domain/client_quote.dart';

class QuoteDetailPage extends ConsumerStatefulWidget {
  const QuoteDetailPage({super.key, required this.quoteId, this.initialQuote});

  final String quoteId;
  final ClientQuote? initialQuote;

  @override
  ConsumerState<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends ConsumerState<QuoteDetailPage> {
  ClientQuote? _quote;
  bool _loading = true;
  bool _usingTestData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.quoteId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'La cotización no tiene un identificador válido.';
      });
      return;
    }

    if (AppConfig.enableMockAuth) {
      setState(() {
        _quote = widget.initialQuote ?? mockQuoteById(widget.quoteId);
        _usingTestData = true;
        _loading = false;
      });
      return;
    }

    try {
      final response = await ref
          .read(quotesApiProvider)
          .getById(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _quote = clientQuoteFromResponse(response);
        _usingTestData = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la cotización. Inténtalo nuevamente.';
      });
    }
  }

  Future<void> _contact(ClientQuote quote, {required bool whatsapp}) async {
    if (_usingTestData) return;
    final digits = _validPhoneDigits(quote.phone);
    if (digits == null) {
      _showMessage('El yonke no tiene un teléfono válido disponible.');
      return;
    }
    final uri = whatsapp
        ? Uri.https('wa.me', '/$digits')
        : Uri(scheme: 'tel', path: '+$digits');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showMessage('No se pudo abrir la aplicación de contacto.');
      }
    } catch (_) {
      _showMessage('No se pudo abrir la aplicación de contacto.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFCFC),
        surfaceTintColor: const Color(0xFFFCFCFC),
        centerTitle: true,
        title: const Text('Detalle de cotización'),
        actions: [
          IconButton(
            tooltip: 'Actualizar cotización',
            onPressed: _loading ? null : _loadQuote,
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
      return _QuoteMessage(
        title: 'No pudimos cargar la cotización',
        message: _error!,
        onRetry: _loadQuote,
      );
    }
    final quote = _quote;
    if (quote == null) {
      return _QuoteMessage(
        title: 'Cotización no encontrada',
        message: 'Esta cotización ya no está disponible.',
        onRetry: _loadQuote,
      );
    }

    final canContact =
        !_usingTestData && _validPhoneDigits(quote.phone) != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: [
        if (_usingTestData) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF147A1D)),
                SizedBox(width: 10),
                Expanded(child: Text('Cotización de prueba.')),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _LargeYonkeLogo(name: quote.yonkeName, url: quote.logoUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.yonkeName,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(quote.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          formatQuotePrice(quote.price),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF147A1D),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _QuoteDetailCard(
          title: 'Información de la pieza',
          children: [
            _QuoteRow(label: 'Disponibilidad', value: quote.availability),
            _QuoteRow(label: 'Condición', value: quote.condition),
            _QuoteRow(label: 'Garantía', value: quote.warranty),
            if (quote.partNumber != null && quote.partNumber!.isNotEmpty)
              _QuoteRow(label: 'Número de parte', value: quote.partNumber!),
            if (quote.deliveryDays != null)
              _QuoteRow(
                label: 'Entrega',
                value:
                    '${quote.deliveryDays} ${quote.deliveryDays == 1 ? 'día' : 'días'}',
              ),
            _QuoteRow(
              label: 'Envío',
              value: quote.shippingAvailable
                  ? quote.shippingCost == null
                        ? 'Disponible'
                        : 'Disponible · ${formatQuotePrice(quote.shippingCost!)}'
                  : 'No disponible',
            ),
          ],
        ),
        if (quote.comments != null && quote.comments!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _QuoteDetailCard(
            title: 'Comentarios del yonke',
            children: [Text(quote.comments!)],
          ),
        ],
        const SizedBox(height: 14),
        _QuoteDetailCard(
          title: 'Fotografías (${quote.imageUrls.length})',
          children: [
            if (quote.imageUrls.isEmpty)
              const Text(
                'El yonke no agregó fotografías a esta cotización.',
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
                itemCount: quote.imageUrls.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    quote.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: canContact ? () => _contact(quote, whatsapp: true) : null,
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Contactar por WhatsApp'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFF14951F),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canContact ? () => _contact(quote, whatsapp: false) : null,
          icon: const Icon(Icons.phone_outlined),
          label: const Text('Llamar al yonke'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Elegir una cotización y crear una orden se habilitará cuando el backend confirme ese flujo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF596276), fontSize: 12),
        ),
      ],
    );
  }
}

class _LargeYonkeLogo extends StatelessWidget {
  const _LargeYonkeLogo({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'Y' : name.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 31,
      backgroundColor: const Color(0xFFE8F5EA),
      foregroundImage: url == null ? null : NetworkImage(url!),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        initial,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QuoteDetailCard extends StatelessWidget {
  const _QuoteDetailCard({required this.title, required this.children});

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

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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

class _QuoteMessage extends StatelessWidget {
  const _QuoteMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });

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
          const Icon(
            Icons.local_offer_outlined,
            size: 54,
            color: Color(0xFF596276),
          ),
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

String? _validPhoneDigits(String? rawPhone) {
  if (rawPhone == null) return null;
  if (!rawPhone.trim().startsWith('+')) return null;
  final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
