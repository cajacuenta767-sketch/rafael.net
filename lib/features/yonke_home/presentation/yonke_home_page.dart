import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../yonke_requests/domain/yonke_request_summary.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';

/// Resumen operativo para el yonke. Los contadores se derivan de los
/// repositorios existentes; nunca se muestran cifras de muestra.
class YonkeHomePage extends ConsumerStatefulWidget {
  const YonkeHomePage({super.key, this.dataLoader});

  /// Permite una fuente controlada en pruebas visuales. En la aplicación real
  /// se omite y el tablero consulta siempre los repositorios de la API.
  final Future<YonkeHomeData> Function()? dataLoader;

  @override
  ConsumerState<YonkeHomePage> createState() => _YonkeHomePageState();
}

class _YonkeHomePageState extends ConsumerState<YonkeHomePage> {
  late Future<YonkeHomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.dataLoader?.call() ?? _load();
  }

  Future<YonkeHomeData> _load() async {
    final requestsRepository = ref.read(yonkeRequestsRepositoryProvider);
    final quotesRepository = ref.read(yonkeQuotesRepositoryProvider);
    final messagesRepository = ref.read(yonkeMessagesRepositoryProvider);
    final profileRepository = ref.read(yonkeProfileRepositoryProvider);

    final requests = await _safe(
      () => requestsRepository.getAssignedRequests(page: 1, pageSize: 20),
    );
    final quotes = await _safe(
      () => quotesRepository.getMyQuotes(page: 1, pageSize: 30),
    );
    final messages = await _safe(messagesRepository.getInbox);
    final profile = await _safe(profileRepository.load);

    return YonkeHomeData(
      requests: requests?.items ?? const [],
      quoteCount: quotes?.items.length ?? 0,
      unreadMessages:
          messages?.fold<int>(0, (total, item) => total + item.unreadCount) ??
          0,
      businessName: profile?.profile?.name,
    );
  }

  Future<T?> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: YonkeColors.background,
    body: SafeArea(
      bottom: false,
      child: FutureBuilder<YonkeHomeData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const YonkeHomeData();
          return RefreshIndicator(
            color: YonkeColors.accentGreen,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Hero(data: data)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                  sliver: SliverList.list(
                    children: [
                      _Metrics(data: data),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Solicitudes recientes',
                              style: TextStyle(
                                color: YonkeColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.yonkeRequests),
                            child: const Text('Ver todas'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 42),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: YonkeColors.accentGreen,
                            ),
                          ),
                        )
                      else if (data.requests.isEmpty)
                        const _EmptyRequests()
                      else
                        ...data.requests
                            .take(3)
                            .map((item) => _RecentRequest(item: item)),
                      const SizedBox(height: 18),
                      const _SalesBanner(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.home,
      onRefresh: _refresh,
    ),
  );
}

class YonkeHomeData {
  const YonkeHomeData({
    this.requests = const [],
    this.quoteCount = 0,
    this.unreadMessages = 0,
    this.businessName,
  });
  final List<YonkeRequestSummary> requests;
  final int quoteCount;
  final int unreadMessages;
  final String? businessName;
  int get newRequests => requests
      .where((item) => item.status == YonkeRequestStatus.newRequest)
      .length;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final YonkeHomeData data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 31),
    decoration: const BoxDecoration(
      color: YonkeColors.primaryNavy,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${data.businessName ?? 'Yonke'}! 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aquí tienes un resumen de tu actividad',
                style: TextStyle(color: Color(0xFFDDE8F8), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => context.push(AppRoutes.yonkeNotifications),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    ),
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data});
  final YonkeHomeData data;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _MetricCard(
          label: 'Solicitudes\nnuevas',
          value: data.newRequests,
          icon: Icons.inbox_outlined,
          color: const Color(0xFF536274),
          onTap: () => context.go(AppRoutes.yonkeRequests),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _MetricCard(
          label: 'Cotizaciones\nenviadas',
          value: data.quoteCount,
          icon: Icons.request_quote_outlined,
          color: YonkeColors.accentGreen,
          onTap: () => context.go(AppRoutes.yonkeQuotes),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _MetricCard(
          label: 'Mensajes\nsin leer',
          value: data.unreadMessages,
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF2B72D6),
          onTap: () => context.go(AppRoutes.yonkeMessages),
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 134,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: YonkeColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D1B3D),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Ver todas →',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentRequest extends StatelessWidget {
  const _RecentRequest({required this.item});
  final YonkeRequestSummary item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => context.push(
          AppRoutes.yonkeRequestDetail(item.requestYonkeId),
          extra: item,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: YonkeColors.border),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: RefanetImage(
                  source: item.imageUrl,
                  fit: BoxFit.cover,
                  fallback: const Icon(
                    Icons.settings_input_component_outlined,
                    color: YonkeColors.primaryNavy,
                    size: 33,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Status(status: item.status),
                    const SizedBox(height: 4),
                    Text(
                      item.part,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (item.city != null)
                      Text(
                        item.city!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: YonkeColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: YonkeColors.primaryNavy),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.status});
  final YonkeRequestStatus status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: YonkeColors.accentGreen.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      status.label.toUpperCase(),
      style: const TextStyle(
        fontSize: 9,
        color: YonkeColors.accentGreen,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: YonkeColors.border),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 38, color: YonkeColors.textSecondary),
        SizedBox(height: 8),
        Text(
          'Aún no tienes solicitudes recientes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'Cuando una solicitud coincida con tu cobertura aparecerá aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(color: YonkeColors.textSecondary),
        ),
      ],
    ),
  );
}

class _SalesBanner extends StatelessWidget {
  const _SalesBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: YonkeColors.primaryNavy,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aumenta tus ventas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Responde rápido y ofrece\nla mejor solución.',
                style: TextStyle(color: Colors.white, height: 1.35),
              ),
            ],
          ),
        ),
        Icon(
          Icons.trending_up_rounded,
          color: YonkeColors.accentGreen,
          size: 52,
        ),
      ],
    ),
  );
}
