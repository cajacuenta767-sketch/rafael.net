import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../domain/client_quote.dart';

class ClientQuotesPage extends ConsumerStatefulWidget {
  const ClientQuotesPage({super.key});

  @override
  ConsumerState<ClientQuotesPage> createState() => _ClientQuotesPageState();
}

class _ClientQuotesPageState extends ConsumerState<ClientQuotesPage> {
  List<ClientQuote> _quotes = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(dashboardApiProvider).getMyQuotes();
      final allQuotes = await ref
          .read(quoteYonkeResolverProvider)
          .resolveAll(clientQuotesFromDashboard(response));
      allQuotes.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      if (!mounted) return;
      setState(() {
        _quotes = allQuotes;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      centerTitle: true,
      title: const Text(
        'Cotizaciones recibidas',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar cotizaciones',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(onRefresh: _load, child: _body()),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: -1),
  );

  Widget _body() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return _State(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos consultar las cotizaciones',
        message: 'Revisa la sesión o conexión e intenta nuevamente.',
        action: _load,
      );
    }
    if (_quotes.isEmpty) {
      return _State(
        icon: Icons.sell_outlined,
        title: 'Aún no recibes cotizaciones',
        message: 'Cuando un yonke responda a tu solicitud aparecerá aquí.',
        action: _load,
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: _quotes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quote = _quotes[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE1E6EC)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            key: Key('client-global-quote-${quote.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(
              AppRoutes.clientQuoteDetail(quote.id),
              extra: quote,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RefanetImage(
                      source: quote.imageUrls.isEmpty
                          ? null
                          : quote.imageUrls.first,
                      fallback: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF269627),
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.partName ?? 'Autoparte cotizada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF07284D),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (_vehicle(quote).isNotEmpty)
                          Text(
                            _vehicle(quote),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF69717D)),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          quote.yonkeName,
                          style: const TextStyle(
                            color: Color(0xFF69717D),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatQuotePrice(quote.price),
                          style: const TextStyle(
                            color: Color(0xFF269627),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          quote.status,
                          style: TextStyle(
                            color: quote.status.toLowerCase().contains('acept')
                                ? const Color(0xFF269627)
                                : const Color(0xFF69717D),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF269627),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _vehicle(ClientQuote quote) => [
    quote.brand,
    quote.model,
    quote.year?.toString(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
}

class _State extends StatelessWidget {
  const _State({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 110),
      Icon(icon, size: 58, color: const Color(0xFF269627)),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Center(
        child: OutlinedButton(
          onPressed: action,
          child: const Text('Actualizar'),
        ),
      ),
    ],
  );
}
