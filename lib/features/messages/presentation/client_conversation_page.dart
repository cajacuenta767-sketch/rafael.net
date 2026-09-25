import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/widgets/refanet_image.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../../quotes/domain/client_quote.dart';
import '../data/client_messages_repository.dart';
import '../domain/client_message.dart';

const _navy = Color(0xFF082B50);
const _green = Color(0xFF56BE20);
const _page = Color(0xFFF8F9FA);
const _muted = Color(0xFF69717D);

class ClientConversationArgs {
  const ClientConversationArgs({required this.quote});

  final ClientQuote quote;
}

class ClientMessagesPage extends ConsumerStatefulWidget {
  const ClientMessagesPage({super.key, this.repository});

  final ClientMessagesRepository? repository;

  @override
  ConsumerState<ClientMessagesPage> createState() => _ClientMessagesPageState();
}

class _ClientMessagesPageState extends ConsumerState<ClientMessagesPage> {
  late final ClientMessagesRepository _repository;
  List<ClientMessagePreview> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(clientMessagesRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.getInbox();
      if (!mounted) return;
      setState(() {
        _items = items;
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
    backgroundColor: _page,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _page,
      surfaceTintColor: _page,
      centerTitle: true,
      title: const Text(
        'Mensajes',
        style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar mensajes',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, color: _navy),
        ),
      ],
    ),
    body: RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text(
            'Conversaciones',
            style: TextStyle(
              color: _navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Consulta el historial de cada cotización.',
            style: TextStyle(color: _muted, fontSize: 15),
          ),
          const SizedBox(height: 18),
          ..._content(),
        ],
      ),
    ),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: 3),
  );

  List<Widget> _content() {
    if (_loading) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: _green)),
      ];
    }
    if (_error != null) {
      return [
        _StateCard(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar tus mensajes',
          message: 'Revisa tu conexión o sesión e inténtalo nuevamente.',
          action: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        _StateCard(
          icon: Icons.forum_outlined,
          title: 'Aún no tienes conversaciones',
          message: 'Cuando recibas una cotización podrás hablar con el yonke desde aquí.',
        ),
      ];
    }
    return _items.map(_conversationTile).toList(growable: false);
  }

  Widget _conversationTile(ClientMessagePreview item) {
    final quote = item.quote;
    final detail = [
      quote.partName,
      _vehicleLabel(quote),
      quote.requestFolio,
    ].whereType<String>().where((text) => text.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFE8EBEF)),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('client-conversation-${quote.id}'),
          onTap: () async {
            await context.push(
              AppRoutes.clientQuoteConversation(quote.id),
              extra: ClientConversationArgs(quote: quote),
            );
            if (mounted) _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _YonkeAvatar(name: quote.yonkeName, url: quote.logoUrl),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quote.yonkeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _previewTime(item.lastMessageAt),
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF303947),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: item.historyAvailable
                                    ? _muted
                                    : const Color(0xFFB15B25),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (item.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: const BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${item.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded, color: _green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClientConversationPage extends ConsumerStatefulWidget {
  const ClientConversationPage({
    super.key,
    required this.args,
    this.repository,
  });

  final ClientConversationArgs args;
  final ClientMessagesRepository? repository;

  @override
  ConsumerState<ClientConversationPage> createState() =>
      _ClientConversationPageState();
}

class _ClientConversationPageState
    extends ConsumerState<ClientConversationPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final ClientMessagesRepository _repository;
  List<ClientQuoteMessage> _messages = const [];
  Timer? _refreshTimer;
  StreamSubscription<String>? _realtime;
  late final RealtimeService _realtimeService;
  late ClientQuote _quote = widget.args.quote;
  bool _loading = true;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(clientMessagesRepositoryProvider);
    _load();
    _resolveYonke();
    // SignalR avisa al instante; el sondeo queda como respaldo por si el hub
    // no acepta la conexión.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSilently(),
    );
    _realtimeService = ref.read(realtimeServiceProvider);
    final quoteId = widget.args.quote.id;
    _realtime = _realtimeService.newMessages
        .where((id) => id == quoteId)
        .listen((_) => _refreshSilently());
    _realtimeService.watchQuote(quoteId);
  }

  /// Nombre y foto del yonke cuando la cotización llegó sin ellos.
  Future<void> _resolveYonke() async {
    if (_quote.hasYonkeIdentity && _quote.logoUrl != null) return;
    final resolved = await ref.read(quoteYonkeResolverProvider).resolve(_quote);
    if (mounted && !identical(resolved, _quote)) {
      setState(() => _quote = resolved);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtime?.cancel();
    _realtimeService.unwatchQuote(widget.args.quote.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _repository.getConversation(widget.args.quote.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _refreshSilently() async {
    if (_loading || _sending || !mounted) return;
    try {
      final messages = await _repository.getConversation(widget.args.quote.id);
      if (!mounted || _sameMessages(_messages, messages)) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {
      // La actualización automática no reemplaza el historial visible.
    }
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (_sending || message.isEmpty || message.length > 1000) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        quoteId: widget.args.quote.id,
        message: message,
      );
      if (!mounted) return;
      _messageController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mensaje enviado.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar el mensaje. Inténtalo nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _explainAttachments() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El API actual del chat solamente permite mensajes de texto.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Chat',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar conversación',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: _navy),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverList.list(
                      children: [
                        _YonkeHeader(quote: quote),
                        const SizedBox(height: 8),
                        _QuoteHeader(quote: quote),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  ..._messageSlivers(),
                ],
              ),
            ),
            _MessageComposer(
              controller: _messageController,
              sending: _sending,
              onAttach: _explainAttachments,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _messageSlivers() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: _green)),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateCard(
            icon: Icons.lock_outline_rounded,
            title: 'No pudimos abrir el historial',
            message:
                'La sesión debe tener autorización para consultar este chat.',
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      ];
    }
    if (_messages.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateCard(
            icon: Icons.chat_bubble_outline,
            title: 'Aún no hay mensajes',
            message: 'Escribe al yonke para iniciar la conversación.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        sliver: SliverList.separated(
          itemCount: _messages.length,
          itemBuilder: (context, index) => _MessageBubble(
            message: _messages[index],
            showDate:
                index == 0 ||
                !_sameDay(_messages[index - 1].sentAt, _messages[index].sentAt),
          ),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
        ),
      ),
    ];
  }
}

class _YonkeHeader extends StatelessWidget {
  const _YonkeHeader({required this.quote});

  final ClientQuote quote;

  @override
  Widget build(BuildContext context) => _HeaderCard(
    child: Row(
      children: [
        _YonkeAvatar(name: quote.yonkeName, url: quote.logoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.yonkeName,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 7),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Cotización disponible',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader({required this.quote});

  final ClientQuote quote;

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicleLabel(quote);
    return _HeaderCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 58,
              height: 58,
              color: const Color(0xFFEAF6E5),
              child: quote.imageUrls.isEmpty
                  ? const Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF269627),
                    )
                  : RefanetImage(
                      source: quote.imageUrls.first,
                      fit: BoxFit.cover,
                      fallback: const Icon(
                        Icons.directions_car_outlined,
                        color: Color(0xFF269627),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.partName ?? 'Cotización de autoparte',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (vehicle != null)
                  Text(
                    vehicle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                if (quote.requestFolio != null)
                  Text(
                    'Solicitud ${quote.requestFolio}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            formatQuotePrice(quote.price),
            style: const TextStyle(
              color: Color(0xFF269627),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8EBEF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('client-message-input'),
                controller: controller,
                enabled: !sending,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF5F6F7),
                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Adjuntar archivo',
                    onPressed: onAttach,
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: _muted,
                      size: 21,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('client-send-message'),
              tooltip: 'Enviar mensaje',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2B9E2D),
                disabledBackgroundColor: const Color(0xFFA8CFA9),
                minimumSize: const Size.square(46),
              ),
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showDate});

  final ClientQuoteMessage message;
  final bool showDate;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (showDate)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            _dateLabel(message.sentAt),
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      Align(
        alignment: message.fromClient
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          padding: const EdgeInsets.fromLTRB(13, 10, 11, 7),
          decoration: BoxDecoration(
            color: message.fromClient ? const Color(0xFF67C83C) : Colors.white,
            border: message.fromClient
                ? null
                : Border.all(color: const Color(0xFFE2E6E9)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: Radius.circular(message.fromClient ? 15 : 4),
              bottomRight: Radius.circular(message.fromClient ? 4 : 15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.fromClient
                      ? Colors.white
                      : const Color(0xFF26313D),
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _time(message.sentAt),
                    style: TextStyle(
                      color: message.fromClient
                          ? const Color(0xFFE8FFE1)
                          : _muted,
                      fontSize: 10,
                    ),
                  ),
                  if (message.fromClient) ...[
                    const SizedBox(width: 3),
                    Icon(
                      message.read
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: const Color(0xFFE8FFE1),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _YonkeAvatar extends StatelessWidget {
  const _YonkeAvatar({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 25,
    backgroundColor: _navy,
    foregroundImage: url == null ? null : NetworkImage(url!),
    onForegroundImageError: url == null ? null : (_, _) {},
    child: Text(
      name.trim().isEmpty ? 'Y' : name.trim().substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2B9E2D), size: 48),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

String? _vehicleLabel(ClientQuote quote) {
  final values = [
    quote.brand,
    quote.model,
    if (quote.year != null) '${quote.year}',
  ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
  return values.isEmpty ? null : values.join(' ');
}

bool _sameMessages(List<ClientQuoteMessage> a, List<ClientQuoteMessage> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].id != b[index].id || a[index].read != b[index].read) {
      return false;
    }
  }
  return true;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateLabel(DateTime value) {
  final now = DateTime.now();
  if (_sameDay(now, value)) return 'Hoy';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(yesterday, value)) return 'Ayer';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _previewTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '';
  return _sameDay(DateTime.now(), value)
      ? _time(value)
      : '${value.day}/${value.month}';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
