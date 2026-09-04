import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../quotes/domain/client_quote.dart';
import '../data/client_ratings_repository.dart';

class ClientRatingArgs {
  const ClientRatingArgs({required this.quote, required this.isDemo});

  final ClientQuote quote;
  final bool isDemo;
}

class ClientRatingPage extends ConsumerStatefulWidget {
  const ClientRatingPage({super.key, required this.args, this.repository});

  final ClientRatingArgs args;
  final ClientRatingsRepository? repository;

  @override
  ConsumerState<ClientRatingPage> createState() => _ClientRatingPageState();
}

class _ClientRatingPageState extends ConsumerState<ClientRatingPage> {
  final _commentController = TextEditingController();
  late final ClientRatingsRepository _repository;
  int _rating = 0;
  bool _sending = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.args.isDemo
            ? const DemoClientRatingsRepository()
            : ref.read(clientRatingsRepositoryProvider));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || _rating == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sending = true);
    try {
      final comment = _commentController.text.trim();
      await _repository.register(
        quoteId: widget.args.quote.id,
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo enviar la calificación. Inténtalo nuevamente.',
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
      centerTitle: true,
      title: const Text('Calificar yonke'),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _submitted ? _Success(args: widget.args) : _form(context),
        ),
      ),
    ),
  );

  Widget _form(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    children: [
      if (widget.args.isDemo) ...[
        const _DemoBanner(),
        const SizedBox(height: 22),
      ],
      CircleAvatar(
        radius: 34,
        backgroundColor: const Color(0xFFE8F5EA),
        child: Text(
          widget.args.quote.yonkeName.substring(0, 1).toUpperCase(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        widget.args.quote.yonkeName,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        '¿Cómo fue tu experiencia con esta cotización?',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF596276)),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final value = index + 1;
          return IconButton(
            key: Key('client-rating-$value'),
            tooltip: '$value de 5',
            iconSize: 42,
            color: value <= _rating
                ? const Color(0xFFF5AA16)
                : const Color(0xFFD1D5DB),
            onPressed: _sending ? null : () => setState(() => _rating = value),
            icon: Icon(value <= _rating ? Icons.star : Icons.star_border),
          );
        }),
      ),
      const SizedBox(height: 8),
      Text(
        _rating == 0
            ? 'Selecciona una calificación'
            : '$_rating de 5 estrellas',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _rating == 0
              ? const Color(0xFF596276)
              : const Color(0xFF1D2939),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 24),
      TextField(
        key: const Key('client-rating-comment'),
        controller: _commentController,
        enabled: !_sending,
        minLines: 3,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Comentario (opcional)',
          hintText: 'Comparte tu experiencia',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 22),
      FilledButton(
        key: const Key('client-submit-rating'),
        onPressed: _sending || _rating == 0 ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: const Color(0xFF00695C),
        ),
        child: _sending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Enviar calificación'),
      ),
    ],
  );
}

class _Success extends StatelessWidget {
  const _Success({required this.args});
  final ClientRatingArgs args;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified_outlined, size: 72, color: Color(0xFF147A1D)),
        const SizedBox(height: 18),
        Text(
          args.isDemo
              ? 'Calificación de prueba enviada'
              : 'Gracias por tu calificación',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tu opinión ayudará a otros clientes a elegir mejor.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF596276)),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go(AppRoutes.clientHome),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFF00695C),
          ),
          child: const Text('Ir al inicio'),
        ),
      ],
    ),
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
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
          child: Text('Calificación de prueba: no se publica realmente.'),
        ),
      ],
    ),
  );
}
