import '../../../app/widgets/responsive_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../requests/domain/client_request.dart';
import 'client_bottom_navigation.dart';

const _navy = Color(0xFF07284D);
const _green = Color(0xFF54B91B);
const _greenDark = Color(0xFF258A1B);
const _muted = Color(0xFF68707C);

class RoleHomePage extends StatelessWidget {
  const RoleHomePage.client({super.key});

  @override
  Widget build(BuildContext context) => const _ClientHomePage();
}

class _ClientHomePage extends StatelessWidget {
  const _ClientHomePage();

  @override
  Widget build(BuildContext context) {
    final smallScreen = MediaQuery.sizeOf(context).width < 380;
    return ResponsiveScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      bottomNavigationBar: const ClientBottomNavigation(currentIndex: 0),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            smallScreen ? 18 : 22,
            10,
            smallScreen ? 18 : 22,
            20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: const _HomeContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth >= 800 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HomeHeader(),
            const SizedBox(height: 24),
            AdaptiveInline(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const _WelcomeArtwork(),
                      const SizedBox(height: 16),
                      _CreateRequestBanner(
                        onTap: () => context.push(AppRoutes.clientNewRequest),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      const _HomeShortcutCards(),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Solicitudes recientes',
                        action: 'Ver todas',
                        onAction: () => context.go(AppRoutes.clientRequests),
                      ),
                      const _RecentRequestCard(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HomeHeader(),
          const SizedBox(height: 12),
          const _WelcomeArtwork(),
          const SizedBox(height: 14),
          _CreateRequestBanner(
            onTap: () => context.push(AppRoutes.clientNewRequest),
          ),
          const SizedBox(height: 14),
          const _HomeShortcutCards(),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Solicitudes recientes',
            action: 'Ver todas',
            onAction: () => context.go(AppRoutes.clientRequests),
          ),
          const SizedBox(height: 4),
          const _RecentRequestCard(),
        ],
      );
    },
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) => AdaptiveInline(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Semantics(
          label: 'REFANET',
          image: true,
          child: ExcludeSemantics(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: AdaptiveInline(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 40,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxWidth: 90,
                        maxHeight: 61,
                        child: Image.asset(
                          'assets/images/refanet_logo_transparent.png',
                          width: 90,
                          height: 61,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'REFA',
                          style: TextStyle(color: _navy),
                        ),
                        TextSpan(
                          text: 'NET',
                          style: TextStyle(color: _greenDark),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Notificaciones',
        onPressed: () => context.push(AppRoutes.clientNotifications),
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: _navy,
          size: 25,
        ),
      ),
    ],
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked =
          box.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final greeting = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, cliente',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: _navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '¿Qué autoparte necesitas hoy?',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.25),
          ),
        ],
      );
      final car = Image.asset(
        'assets/images/home_hero_car_parts_v3.png',
        height: stacked ? 110 : 164,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  greeting,
                  Align(alignment: Alignment.centerRight, child: car),
                ],
              )
            : AdaptiveInline(
                children: [
                  Expanded(flex: 4, child: greeting),
                  const SizedBox(width: 8),
                  Expanded(flex: 6, child: car),
                ],
              ),
      );
    },
  );
}

class _CreateRequestBanner extends StatelessWidget {
  const _CreateRequestBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: const LinearGradient(colors: [_green, _greenDark]),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3354B91B),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 19),
          child: AdaptiveInline(
            children: [
              Icon(Icons.add, color: Colors.white, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva solicitud',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Publica la autoparte que buscas',
                      style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final int? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(minHeight: 156),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFEDEFF1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A16233A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _greenDark, size: 31),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value?.toString() ?? '—',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            AdaptiveInline(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _greenDark,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeShortcutCards extends ConsumerStatefulWidget {
  const _HomeShortcutCards();

  @override
  ConsumerState<_HomeShortcutCards> createState() => _HomeShortcutCardsState();
}

class _HomeShortcutCardsState extends ConsumerState<_HomeShortcutCards> {
  int? _requestCount;
  int? _quoteCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1. Intentar resumen rápido de contadores (un solo viaje de red ~15ms)
      try {
        final summaryResponse = await ref
            .read(dashboardApiProvider)
            .getSummary();
        final data = summaryResponse is Map
            ? summaryResponse['data'] ?? summaryResponse
            : summaryResponse;
        if (data is Map) {
          final reqTotal =
              (data['totalSolicitudes'] ??
                      data['solicitudes'] ??
                      data['totalRequests'])
                  as num?;
          final quoteTotal =
              (data['totalCotizaciones'] ??
                      data['cotizaciones'] ??
                      data['totalQuotes'])
                  as num?;
          if (reqTotal != null || quoteTotal != null) {
            if (!mounted) return;
            setState(() {
              _requestCount = reqTotal?.toInt() ?? 0;
              _quoteCount = quoteTotal?.toInt() ?? 0;
            });
            return;
          }
        }
      } catch (_) {
        // Fallback a consulta ligera
      }

      final responses = await Future.wait<dynamic>([
        ref.read(dashboardApiProvider).getMyRequests(pageSize: 1),
        ref.read(dashboardApiProvider).getMyQuotes(),
      ]);
      var count = _recordCount(responses[0]);
      if (count == 0) {
        try {
          final recentResponse = await ref
              .read(dashboardApiProvider)
              .getRecentRequest();
          if (clientRequestSummaryFromResponse(recentResponse) != null) {
            count = 1;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _requestCount = count;
        _quoteCount = _recordCount(responses[1]);
      });
    } catch (_) {
      // Sin datos del servidor los contadores quedan vacíos; no se inventan.
    }
  }

  @override
  Widget build(BuildContext context) => ResponsiveRow(
    minItemWidth: 130,
    children: [
      Expanded(
        child: _ShortcutCard(
          icon: Icons.assignment_outlined,
          title: 'Mis solicitudes',
          subtitle: 'Ver mis solicitudes',
          value: _requestCount,
          onTap: () => context.go(AppRoutes.clientRequests),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ShortcutCard(
          icon: Icons.sell_outlined,
          title: 'Cotizaciones',
          subtitle: 'Cotizaciones recibidas',
          value: _quoteCount,
          onTap: () => context.go(AppRoutes.clientQuotes),
        ),
      ),
    ],
  );
}

int _recordCount(dynamic response) {
  final data = response is Map ? response['data'] ?? response : response;
  if (data is List) return data.length;
  if (data is Map) {
    final meta = data['meta'];
    if (meta is Map) {
      final metaCount = meta['itemCount'] ?? meta['total'] ?? meta['count'];
      if (metaCount is num) return metaCount.toInt();
    }
    const totalKeys = <String>[
      'total',
      'totalRegistros',
      'cantidadTotal',
      'totalCount',
      'recordCount',
      'itemCount',
    ];
    for (final key in totalKeys) {
      final value = data[key];
      if (value is num) return value.toInt();
    }
    final records = data['items'] ?? data['registros'];
    if (records is List) return records.length;
    final nested = data['data'];
    if (nested != null && !identical(nested, data)) {
      return _recordCount(nested);
    }
  }
  return 0;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => AdaptiveInline(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: _navy, fontWeight: FontWeight.w800),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(foregroundColor: _greenDark),
        child: Text(action),
      ),
    ],
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
  List<ClientRequestSummary> _requests = const [];
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
      final response = await ref
          .read(dashboardApiProvider)
          .getMyRequests(pageSize: 3);
      var requests = clientRequestSummariesFromResponse(response)
          .take(3)
          .toList();
      if (requests.isEmpty) {
        try {
          final recentResponse = await ref
              .read(dashboardApiProvider)
              .getRecentRequest();
          final recent = clientRequestSummaryFromResponse(recentResponse);
          if (recent != null) {
            requests = [recent];
          }
        } catch (_) {}
      }
      if (!mounted) return;
      // Mostrar de inmediato los datos de las solicitudes sin bloquear la UI
      setState(() {
        _requests = requests;
        _loading = false;
      });

      // Si alguna solicitud no tiene imagen, se hidrata en segundo plano sin spinner ni bloqueo
      if (requests.isNotEmpty &&
          requests.any((r) => r.imageUrl == null || r.imageUrl!.isEmpty)) {
        _hydrateImages(requests);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _hydrateImages(List<ClientRequestSummary> initial) async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-recent-request'),
        borderRadius: BorderRadius.circular(14),
        onTap: _requests.isEmpty
            ? () => context.go(AppRoutes.clientRequests)
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDEFF1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A16233A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _loading
              ? const _RecentRequestSkeleton()
              : _failed
              ? _RecentRequestMessage(
                  text: 'No pudimos consultar tu última solicitud.',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : _requests.isEmpty
              ? _RecentRequestMessage(
                  text: 'Aún no tienes solicitudes.',
                  actionLabel: 'Crear solicitud',
                  onAction: () => context.push(AppRoutes.clientNewRequest),
                )
              : Column(
                  children: [
                    for (var index = 0; index < _requests.length; index++) ...[
                      if (index > 0) const Divider(height: 18),
                      _RecentRequestTile(request: _requests[index]),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _RecentRequestTile extends StatelessWidget {
  const _RecentRequestTile({required this.request});
  final ClientRequestSummary request;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(AppRoutes.clientRequestDetail(request.id)),
    borderRadius: BorderRadius.circular(10),
    child: AdaptiveInline(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3E1),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: RefanetImage(
            source: request.imageUrl,
            fallback: const Icon(
              Icons.directions_car_filled_outlined,
              color: _greenDark,
              size: 35,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.part,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (request.vehicle.isNotEmpty)
                Text(
                  request.vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              const SizedBox(height: 6),
              Text(
                '${request.quoteCount} ${request.quoteCount == 1 ? 'cotización' : 'cotizaciones'}',
                style: const TextStyle(
                  color: _greenDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: _greenDark, size: 25),
      ],
    ),
  );
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
  Widget build(BuildContext context) => AdaptiveInline(
    children: [
      const Icon(Icons.assignment_outlined, color: _greenDark),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: const TextStyle(color: _muted, fontSize: 13)),
      ),
      TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}

class _RecentRequestSkeleton extends StatelessWidget {
  const _RecentRequestSkeleton();

  @override
  Widget build(BuildContext context) => AdaptiveInline(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 90,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 110,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
