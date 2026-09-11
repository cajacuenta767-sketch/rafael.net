import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/storage/session_sync_store.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  smallScreen ? 18 : 22,
                  10,
                  smallScreen ? 18 : 22,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const _HomeContent(),
                  ),
                ),
              ),
            ),
            const ClientBottomNavigation(currentIndex: 0),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) => Column(
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Semantics(
        label: 'REFANET',
        image: true,
        child: ExcludeSemantics(
          child: Row(
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
  Widget build(BuildContext context) => Container(
    height: 164,
    width: double.infinity,
    color: Colors.white,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .64,
              heightFactor: 1,
              child: Image.asset(
                'assets/images/home_hero_car_v2.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, cliente',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: _navy, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const SizedBox(
                width: 160,
                child: Text(
                  '¿Qué autoparte necesitas hoy?',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
        height: 84,
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
          child: Row(
            children: [
              Icon(Icons.add, color: Colors.white, size: 34),
              SizedBox(width: 14),
              Column(
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
              Spacer(),
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
        height: 156,
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
            const Spacer(),
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
            Row(
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
      final responses = await Future.wait<dynamic>([
        ref.read(dashboardApiProvider).getMyRequests(pageSize: 100),
        ref.read(dashboardApiProvider).getMyQuotes(),
      ]);
      var count = _recordCount(responses[0]);
      if (count == 0) {
        try {
          final recentResponse =
              await ref.read(dashboardApiProvider).getRecentRequest();
          if (clientRequestSummaryFromResponse(recentResponse) != null) {
            count = 1;
          }
        } catch (_) {}
      }
      final sessionReqCount = SessionSyncStore.instance.clientRequests.length;
      final sessionQuoteCount = SessionSyncStore.instance.clientQuotes.length;
      if (!mounted) return;
      setState(() {
        _requestCount = count + sessionReqCount;
        _quoteCount = _recordCount(responses[1]) + sessionQuoteCount;
      });
    } catch (_) {
      final sessionReqCount = SessionSyncStore.instance.clientRequests.length;
      final sessionQuoteCount = SessionSyncStore.instance.clientQuotes.length;
      if (!mounted) return;
      setState(() {
        _requestCount = sessionReqCount;
        _quoteCount = sessionQuoteCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Row(
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
  Widget build(BuildContext context) => Row(
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
      var requests =
          clientRequestSummariesFromResponse(response).take(3).toList();
      if (requests.isEmpty) {
        try {
          final recentResponse =
              await ref.read(dashboardApiProvider).getRecentRequest();
          final recent = clientRequestSummaryFromResponse(recentResponse);
          if (recent != null) {
            requests = [recent];
          }
        } catch (_) {}
      }
      final sessionRequests = SessionSyncStore.instance.clientRequests;
      final existingIds = requests.map((r) => r.id).toSet();
      final merged = [
        ...sessionRequests.where((r) => !existingIds.contains(r.id)),
        ...requests,
      ].take(3).toList();
      if (!mounted) return;
      setState(() {
        _requests = merged;
        _loading = false;
      });
    } catch (_) {
      final sessionRequests = SessionSyncStore.instance.clientRequests;
      if (!mounted) return;
      if (sessionRequests.isNotEmpty) {
        setState(() {
          _requests = sessionRequests.take(3).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
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
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
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
    child: Row(
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
  Widget build(BuildContext context) => Row(
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
