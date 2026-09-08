import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../home/presentation/client_bottom_navigation.dart';
import '../../messages/data/client_messages_repository.dart';
import '../../messages/domain/client_message.dart';
import '../../messages/presentation/client_conversation_page.dart';

class ClientNotificationsPage extends ConsumerStatefulWidget {
  const ClientNotificationsPage({super.key, this.repository});

  final ClientMessagesRepository? repository;

  @override
  ConsumerState<ClientNotificationsPage> createState() =>
      _ClientNotificationsPageState();
}

class _ClientNotificationsPageState
    extends ConsumerState<ClientNotificationsPage> {
  late Future<List<ClientMessagePreview>> _items;
  late final ClientMessagesRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(clientMessagesRepositoryProvider);
    _items = _repository.getInbox();
  }

  void _reload() => setState(() => _items = _repository.getInbox());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF8F9FA),
      surfaceTintColor: const Color(0xFFF8F9FA),
      centerTitle: true,
      title: const Text(
        'Notificaciones',
        style: TextStyle(color: Color(0xFF07284D), fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<ClientMessagePreview>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF41B928)),
          );
        }
        if (snapshot.hasError) {
          return _State(
            message: 'No pudimos cargar tus notificaciones.',
            onTap: _reload,
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _State(
            message: 'Aún no tienes cotizaciones ni mensajes nuevos.',
            onTap: _reload,
          );
        }
        return RefreshIndicator(
          color: const Color(0xFF41B928),
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              if (index == items.length) {
                return TextButton(
                  onPressed: () => context.go(AppRoutes.clientMessages),
                  child: const Text('Ver todas'),
                );
              }
              final item = items[index];
              final isMessage = item.unreadCount > 0;
              return ListTile(
                key: Key('client-notification-${item.quote.id}'),
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
                leading: Icon(
                  isMessage
                      ? Icons.markunread_outlined
                      : Icons.notifications_active_outlined,
                  color: isMessage
                      ? const Color(0xFF2E9D2A)
                      : const Color(0xFF2584D9),
                ),
                title: Text(
                  isMessage ? 'Mensaje nuevo' : 'Nueva cotización recibida',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  isMessage
                      ? '${item.quote.yonkeName} · ${item.lastMessage}'
                      : '${item.quote.yonkeName} envió una cotización${item.quote.partName == null ? '' : ' para ${item.quote.partName}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _when(item.lastMessageAt),
                  style: const TextStyle(
                    color: Color(0xFF8A919A),
                    fontSize: 11,
                  ),
                ),
                onTap: () => _open(item),
              );
            },
          ),
        );
      },
    ),
    bottomNavigationBar: const ClientBottomNavigation(currentIndex: -1),
  );

  Future<void> _open(ClientMessagePreview item) async {
    if (item.unreadCount > 0 && item.historyAvailable) {
      await context.push(
        AppRoutes.clientQuoteConversation(item.quote.id),
        extra: ClientConversationArgs(quote: item.quote),
      );
    } else {
      await context.push(
        AppRoutes.clientQuoteDetail(item.quote.id),
        extra: item.quote,
      );
    }
    if (mounted) _reload();
  }
}

class _State extends StatelessWidget {
  const _State({required this.message, required this.onTap});
  final String message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.notifications_none,
          size: 54,
          color: Color(0xFF41B928),
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onTap, child: const Text('Reintentar')),
      ],
    ),
  );
}

String _when(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}
