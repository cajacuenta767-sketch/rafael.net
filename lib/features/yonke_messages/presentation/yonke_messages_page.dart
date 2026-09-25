import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../yonke_quotes/domain/yonke_quote.dart';
import '../../../app/theme/yonke_theme.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';
import '../data/yonke_messages_repository.dart';
import '../domain/quote_client.dart';
import '../domain/yonke_message.dart';

class YonkeConversationArgs {
  const YonkeConversationArgs({required this.quote, this.client});

  final YonkeQuote quote;
  final QuoteClient? client;
}

class YonkeMessagesPage extends ConsumerStatefulWidget {
  const YonkeMessagesPage({super.key, this.repository});

  final YonkeMessagesRepository? repository;

  @override
  ConsumerState<YonkeMessagesPage> createState() => _YonkeMessagesPageState();
}

class _YonkeMessagesPageState extends ConsumerState<YonkeMessagesPage> {
  late final YonkeMessagesRepository _repository;
  List<YonkeMessagePreview> _items = const [];
  bool _loading = true;
  bool _contractPending = false;
  Object? _error;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(yonkeMessagesRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _contractPending = false;
      _error = null;
    });
    try {
      final items = await _repository.getInbox();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on YonkeMessagesInboxContractPendingException {
      if (mounted) {
        setState(() {
          _contractPending = true;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: YonkeColors.primaryNavy,
      surfaceTintColor: YonkeColors.primaryNavy,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: const Text(
        'Mensajes',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar mensajes',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                14,
                MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
                28,
              ),
              children: [
                _MessageTabs(
                  unreadOnly: _unreadOnly,
                  unreadCount: _items
                      .where((item) => item.unreadCount > 0)
                      .length,
                  onChanged: (value) => setState(() => _unreadOnly = value),
                ),
                const SizedBox(height: 14),
                ..._content(),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.messages,
      onRefresh: _load,
    ),
  );

  List<Widget> _content() {
    if (_loading) {
      return const [
        SizedBox(height: 96),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (_contractPending) {
      return const [
        _StateCard(
          icon: Icons.rule_folder_outlined,
          title: 'Aún no hay conversaciones',
          message:
              'Aquí aparecen los chats de las cotizaciones que envíes desde '
              'la app y de los mensajes nuevos que te lleguen. El servidor '
              'todavía no entrega la lista completa de tus cotizaciones.',
        ),
      ];
    }
    if (_error != null) {
      return [
        _StateCard(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar los mensajes',
          message: 'Revisa tu conexión e inténtalo nuevamente.',
          action: OutlinedButton(
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }
    final visible = _unreadOnly
        ? _items.where((item) => item.unreadCount > 0).toList()
        : _items;
    if (visible.isEmpty) {
      return const [
        _StateCard(
          icon: Icons.chat_bubble_outline,
          title: 'No hay mensajes en esta sección',
          message:
              'Cuando un cliente escriba sobre una cotización, aparecerá aquí.',
        ),
      ];
    }
    return visible.map(_conversationTile).toList(growable: false);
  }

  Widget _conversationTile(YonkeMessagePreview item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE1E6EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        key: Key('yonke-conversation-${item.quote.id}'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        leading: _ClientAvatar(
          name: item.client?.name,
          photoUrl: item.client?.photoUrl,
        ),
        title: Text(
          item.clientLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              item.quote.part,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              item.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _time(item.lastMessageAt),
              style: const TextStyle(color: Color(0xFF596276), fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (item.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFF114EB0),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${item.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        onTap: () async {
          await context.push(
            AppRoutes.yonkeConversation(item.quote.id),
            extra: YonkeConversationArgs(
              quote: item.quote,
              client: item.client,
            ),
          );
          if (mounted) await _load();
        },
      ),
    ),
  );
}

class _MessageTabs extends StatelessWidget {
  const _MessageTabs({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onChanged,
  });
  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: YonkeColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: _MessageTab(
            label: 'Todos',
            selected: !unreadOnly,
            onTap: () => onChanged(false),
          ),
        ),
        Expanded(
          child: _MessageTab(
            label: 'No leídos ($unreadCount)',
            selected: unreadOnly,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _MessageTab extends StatelessWidget {
  const _MessageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? YonkeColors.primaryNavy
                  : YonkeColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: 55,
            color: selected ? YonkeColors.primaryNavy : Colors.transparent,
          ),
        ],
      ),
    ),
  );
}

class YonkeConversationPage extends ConsumerStatefulWidget {
  const YonkeConversationPage({super.key, required this.args, this.repository});

  final YonkeConversationArgs args;
  final YonkeMessagesRepository? repository;

  @override
  ConsumerState<YonkeConversationPage> createState() =>
      _YonkeConversationPageState();
}

class _YonkeConversationPageState extends ConsumerState<YonkeConversationPage> {
  final _messageController = TextEditingController();
  late final YonkeMessagesRepository _repository;
  List<YonkeQuoteMessage> _messages = const [];
  QuoteClient? _client;
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  Timer? _refreshTimer;
  StreamSubscription<String>? _realtime;
  late final RealtimeService _realtimeService;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(yonkeMessagesRepositoryProvider);
    _client = widget.args.client;
    _load();
    if (_client == null) _loadClient();
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtime?.cancel();
    _realtimeService.unwatchQuote(widget.args.quote.id);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refreshSilently() async {
    if (_loading || _sending || !mounted) return;
    try {
      final messages = await _repository.getConversation(widget.args.quote.id);
      if (!mounted || messages.length == _messages.length) return;
      setState(() {
        _messages = messages;
        _client = _contactIn(messages) ?? _client;
      });
    } catch (_) {
      // La actualización automática no reemplaza el historial visible.
    }
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
        _client = _contactIn(messages) ?? _client;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  /// El contacto más reciente que el cliente envió en el chat.
  static QuoteClient? _contactIn(List<YonkeQuoteMessage> messages) => messages
      .reversed
      .map((message) => message.contact)
      .firstWhere((contact) => contact != null, orElse: () => null);

  Future<void> _loadClient() async {
    try {
      final client = await _repository.getClient(widget.args.quote.id);
      if (mounted && client != null && _client == null) {
        setState(() => _client = client);
      }
    } catch (_) {
      // Sin datos del cliente se muestra "Cliente".
    }
  }

  Future<void> _contact({required bool whatsapp}) async {
    final digits = _validPhoneDigits(_client?.phone);
    if (digits == null) return;
    final uri = whatsapp
        ? Uri.https('wa.me', '/$digits')
        : Uri(scheme: 'tel', path: '+$digits');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Se avisa abajo.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir la aplicación de contacto.'),
      ),
    );
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
      // Se vuelve a leer el historial del servidor para mostrar el mensaje
      // con su identificador y hora reales.
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_client?.name ?? 'Cliente'),
          Text(
            widget.args.quote.part,
            style: const TextStyle(fontSize: 12, color: Color(0xFF596276)),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar conversación',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          _ClientHeader(
            client: _client,
            quote: widget.args.quote,
            onCall: () => _contact(whatsapp: false),
            onWhatsApp: () => _contact(whatsapp: true),
          ),
          Expanded(child: _messagesBody()),
          _Composer(
            controller: _messageController,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    ),
  );

  Widget _messagesBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Aún no hay mensajes. Escribe al cliente para iniciar la conversación.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) =>
          _MessageBubble(message: _messages[index]),
    );
  }
}

/// Equivalente a la cabecera del yonke que ve el cliente en su chat.
class _ClientHeader extends StatelessWidget {
  const _ClientHeader({
    required this.client,
    required this.quote,
    required this.onCall,
    required this.onWhatsApp,
  });

  final QuoteClient? client;
  final YonkeQuote quote;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final phone = client?.phone;
    final canContact = _validPhoneDigits(phone) != null;
    final details = [
      quote.folio,
      if (quote.vehicle.isNotEmpty) quote.vehicle,
    ].whereType<String>().join(' · ');
    return Container(
      key: const Key('yonke-conversation-client'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E6EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ClientAvatar(name: client?.name, photoUrl: client?.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client?.name ?? 'Cliente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: YonkeColors.primaryNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone ?? 'Teléfono no disponible',
                  style: const TextStyle(
                    color: Color(0xFF596276),
                    fontSize: 13,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF596276),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (canContact) ...[
            IconButton(
              key: const Key('yonke-call-client'),
              tooltip: 'Llamar al cliente',
              onPressed: onCall,
              icon: const Icon(Icons.phone_outlined, color: Color(0xFF114EB0)),
            ),
            IconButton(
              key: const Key('yonke-whatsapp-client'),
              tooltip: 'WhatsApp del cliente',
              onPressed: onWhatsApp,
              icon: const Icon(Icons.chat_outlined, color: Color(0xFF1B8F3A)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name, required this.photoUrl});

  final String? name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = (name ?? '').trim();
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFEAF1FF),
      foregroundColor: const Color(0xFF114EB0),
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      onForegroundImageError: photoUrl == null ? null : (_, _) {},
      child: Text(
        initial.isEmpty ? 'C' : initial.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 6,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('yonke-message-input'),
                controller: controller,
                enabled: !sending,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje',
                  counterText: '',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('yonke-send-message'),
              tooltip: 'Enviar mensaje',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF114EB0),
              ),
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final YonkeQuoteMessage message;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromClient
        ? Alignment.centerLeft
        : Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 330),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: message.fromClient ? Colors.white : const Color(0xFF114EB0),
        border: message.fromClient
            ? Border.all(color: const Color(0xFFE1E6EC))
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.fromClient
                  ? const Color(0xFF1D2939)
                  : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _time(message.sentAt),
            style: TextStyle(
              color: message.fromClient
                  ? const Color(0xFF596276)
                  : const Color(0xFFDCE7FF),
              fontSize: 11,
            ),
          ),
        ],
      ),
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
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      children: [
        Icon(icon, size: 52, color: const Color(0xFF596276)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF596276)),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Solo números en formato internacional (+52...), igual que el contacto
/// del yonke en la app del cliente.
String? _validPhoneDigits(String? rawPhone) {
  if (rawPhone == null || !rawPhone.trim().startsWith('+')) return null;
  final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}
