import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../yonke_quotes/domain/yonke_quote.dart';
import '../../yonke_requests/presentation/yonke_bottom_navigation.dart';
import '../data/yonke_messages_repository.dart';
import '../domain/yonke_message.dart';

class YonkeConversationArgs {
  const YonkeConversationArgs({
    required this.quote,
    required this.isDemoSession,
  });

  final YonkeQuote quote;
  final bool isDemoSession;
}

class YonkeMessagesPage extends ConsumerStatefulWidget {
  const YonkeMessagesPage({
    super.key,
    required this.isDemoSession,
    this.repository,
  });

  final bool isDemoSession;
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

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.isDemoSession
            ? const DemoYonkeMessagesRepository()
            : ref.read(yonkeMessagesRepositoryProvider));
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
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      automaticallyImplyLeading: false,
      title: const Text('Mensajes'),
      actions: [
        IconButton(
          tooltip: 'Actualizar mensajes',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
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
                Text(
                  'Conversaciones',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF092B61),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Habla con el cliente sobre cada cotización.',
                  style: TextStyle(color: Color(0xFF596276)),
                ),
                if (_repository.usesDemoData) ...[
                  const SizedBox(height: 14),
                  const _DemoBanner(),
                ],
                const SizedBox(height: 18),
                ..._content(),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: YonkeBottomNavigation(
      selected: YonkeNavigationSection.messages,
      isDemoSession: widget.isDemoSession,
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
          title: 'Bandeja pendiente de conexión',
          message: 'La API permite consultar una conversación por cotización, pero todavía no publica una lista de conversaciones del yonke autenticado.',
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
    if (_items.isEmpty) {
      return const [
        _StateCard(
          icon: Icons.chat_bubble_outline,
          title: 'Todavía no tienes conversaciones',
          message:
              'Cuando un cliente escriba sobre una cotización, aparecerá aquí.',
        ),
      ];
    }
    return _items.map(_conversationTile).toList(growable: false);
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
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF1FF),
          foregroundColor: const Color(0xFF114EB0),
          child: Text(item.clientLabel.substring(0, 1)),
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
        onTap: () => context.push(
          AppRoutes.yonkeConversation(item.quote.id),
          extra: YonkeConversationArgs(
            quote: item.quote,
            isDemoSession: widget.isDemoSession,
          ),
        ),
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
  bool _loading = true;
  bool _historyContractPending = false;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.args.isDemoSession
            ? const DemoYonkeMessagesRepository()
            : ref.read(yonkeMessagesRepositoryProvider));
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.getConversation(widget.args.quote.id);
      if (!mounted) return;
      setState(() {
        _messages = result.messages;
        _historyContractPending = result.historyContractPending;
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
      setState(() {
        _messages = [
          ..._messages,
          YonkeQuoteMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            text: message,
            sentAt: DateTime.now(),
            fromClient: false,
            localOnly: _historyContractPending,
          ),
        ];
        _messageController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _historyContractPending
                ? 'Mensaje enviado. El historial se actualizará cuando la API documente su respuesta.'
                : 'Mensaje enviado.',
          ),
        ),
      );
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
          const Text('Cliente'),
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
          if (widget.args.isDemoSession) const _DemoBanner(compact: true),
          if (_historyContractPending) const _ContractBanner(),
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
            '${_time(message.sentAt)}${message.localOnly ? ' · Pendiente de historial' : ''}',
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

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.fromLTRB(16, compact ? 8 : 0, 16, compact ? 0 : 0),
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
            'Mensajes de prueba: no representan conversaciones reales.',
          ),
        ),
      ],
    ),
  );
}

class _ContractBanner extends StatelessWidget {
  const _ContractBanner();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'La API no documenta el formato del historial. Puedes enviar un mensaje; se mostrará localmente hasta que el backend confirme la respuesta.',
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
