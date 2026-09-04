import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/api_providers.dart';
import '../../quotes/domain/client_quote.dart';
import '../data/client_messages_repository.dart';
import '../domain/client_message.dart';

class ClientConversationArgs {
  const ClientConversationArgs({required this.quote, required this.isDemo});

  final ClientQuote quote;
  final bool isDemo;
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
  late final ClientMessagesRepository _repository;
  List<ClientQuoteMessage> _messages = const [];
  bool _loading = true;
  bool _historyContractPending = false;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.args.isDemo
            ? const DemoClientMessagesRepository()
            : ref.read(clientMessagesRepositoryProvider));
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
          ClientQuoteMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            text: message,
            sentAt: DateTime.now(),
            fromClient: true,
            localOnly: _historyContractPending,
          ),
        ];
        _messageController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _historyContractPending
                ? 'Mensaje enviado. El historial se actualizará cuando la API confirme su formato.'
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
    backgroundColor: const Color(0xFFFCFCFC),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFCFCFC),
      surfaceTintColor: const Color(0xFFFCFCFC),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.args.quote.yonkeName),
          const Text(
            'Conversación sobre tu cotización',
            style: TextStyle(fontSize: 12, color: Color(0xFF596276)),
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
          if (_repository.usesDemoData) const _DemoBanner(),
          if (_historyContractPending) const _ContractBanner(),
          Expanded(child: _messagesBody()),
          _MessageComposer(
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
            'Aún no hay mensajes. Escribe al yonke para iniciar la conversación.',
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

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
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
                key: const Key('client-message-input'),
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
              key: const Key('client-send-message'),
              tooltip: 'Enviar mensaje',
              onPressed: sending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
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

  final ClientQuoteMessage message;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromClient
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 330),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: message.fromClient ? const Color(0xFF00695C) : Colors.white,
        border: message.fromClient
            ? null
            : Border.all(color: const Color(0xFFE1E6EC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: message.fromClient
                  ? Colors.white
                  : const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_time(message.sentAt)}${message.localOnly ? ' · Pendiente de historial' : ''}',
            style: TextStyle(
              color: message.fromClient
                  ? const Color(0xFFCDEDE7)
                  : const Color(0xFF596276),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
      color: const Color(0xFFE8F5EA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'La API no documenta aún el formato del historial. Puedes enviar un mensaje; se mostrará localmente hasta que el backend confirme esa respuesta.',
    ),
  );
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
