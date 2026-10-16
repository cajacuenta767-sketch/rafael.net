import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/api_providers.dart';
import '../core/permissions/app_permissions.dart';
import '../core/push/push_service.dart';
import '../core/session/session_events.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/status_colors.dart';

class YonkeApp extends ConsumerStatefulWidget {
  const YonkeApp({super.key});

  @override
  ConsumerState<YonkeApp> createState() => _YonkeAppState();
}

class _YonkeAppState extends ConsumerState<YonkeApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _subscriptions = <StreamSubscription<Object?>>[];
  late final PushService _push;

  @override
  void initState() {
    super.initState();
    final push = _push = ref.read(pushServiceProvider);
    _subscriptions
      ..add(SessionEvents.expired.listen((_) => _onSessionExpired()))
      // El push y el tiempo real siguen a la sesión guardada.
      ..add(SessionEvents.signedIn.listen((_) => push.registerCurrentSession()))
      ..add(SessionEvents.signedOut.listen((_) => _onSignedOut()))
      ..add(push.openedNotices.listen(_openNotice))
      ..add(push.foregroundNotices.listen(_onForegroundNotice));
    // Un aviso de mensaje nuevo trae la cotización: el yonke la agrega a su
    // bandeja aunque la haya enviado desde otro teléfono.
    push.inbox.addListener(_rememberQuotesFromNotices);
    // Una sesión que sigue abierta desde la ejecución anterior.
    push.registerCurrentSession();
    // Solicitar permisos nativos al iniciar la aplicación (notificaciones, micrófono, almacenamiento)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppPermissions.requestStartupPermissions();
    });
  }

  OverlayEntry? _activeBanner;

  void _onForegroundNotice(PushNotice notice) {
    HapticFeedback.vibrate();
    _showTopBanner(notice);
  }

  void _showTopBanner(PushNotice notice) {
    _activeBanner?.remove();
    _activeBanner = null;

    final overlay = appRouter.routerDelegate.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopNoticeBanner(
        notice: notice,
        onTap: () {
          entry.remove();
          _activeBanner = null;
          _openNotice(notice);
        },
        onDismiss: () {
          entry.remove();
          _activeBanner = null;
        },
      ),
    );

    _activeBanner = entry;
    overlay.insert(entry);
  }

  void _rememberQuotesFromNotices() {
    final notices = _push.inbox.value;
    if (notices.isEmpty) return;
    final latest = notices.first;
    final quoteId = latest.targetId;
    if (latest.isNewMessage && quoteId != null) {
      ref.read(yonkeQuoteRegistryProvider).add(quoteId);
    }
  }

  @override
  void dispose() {
    _activeBanner?.remove();
    _activeBanner = null;
    _push.inbox.removeListener(_rememberQuotesFromNotices);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _onSignedOut() {
    ref.read(pushServiceProvider).unregister();
    ref.read(realtimeServiceProvider).stop();
  }

  /// Abre la pantalla del aviso que el usuario tocó.
  Future<void> _openNotice(PushNotice notice) async {
    final isYonke =
        (await ref.read(tokenStoreProvider).readYonkeGuidId())?.isNotEmpty ==
        true;
    final target = notice.targetId;
    if (isYonke) {
      if (notice.isNewMessage) {
        appRouter.go(AppRoutes.yonkeMessages);
      } else if (target != null && target.isNotEmpty) {
        appRouter.push(AppRoutes.yonkeRequestDetail(target));
      } else {
        appRouter.go(AppRoutes.yonkeRequests);
      }
    } else if (notice.isNewMessage && target != null) {
      appRouter.go(AppRoutes.clientQuoteDetail(target));
    } else {
      appRouter.go(AppRoutes.clientNotifications);
    }
  }

  /// Lleva al login del rol activo. Varias peticiones pueden recibir 401 a la
  /// vez; solo la primera redirige.
  void _onSessionExpired() {
    final location = appRouter.routerDelegate.currentConfiguration.uri.path;
    final login = location.startsWith('/yonke')
        ? AppRoutes.yonkeLogin
        : AppRoutes.clientLogin;
    if (location == login) return;
    appRouter.go(login);
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Refanet Yonke',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}

class _TopNoticeBanner extends StatefulWidget {
  const _TopNoticeBanner({
    required this.notice,
    required this.onTap,
    required this.onDismiss,
  });

  final PushNotice notice;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_TopNoticeBanner> createState() => _TopNoticeBannerState();
}

class _TopNoticeBannerState extends State<_TopNoticeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _dismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = AppStatusColors.fromStatus(
      '${widget.notice.title} ${widget.notice.body}',
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B3D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.notice.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.notice.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFDDE8F8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
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
}
