import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/di/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/request_submission_repository.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission.dart';

class RequestReviewPage extends ConsumerStatefulWidget {
  const RequestReviewPage({super.key, required this.draft, this.repository});

  final RequestDraft draft;
  final RequestSubmissionRepository? repository;

  @override
  ConsumerState<RequestReviewPage> createState() => _RequestReviewPageState();
}

class _RequestReviewPageState extends ConsumerState<RequestReviewPage> {
  late final RequestSubmissionRepository _repository;
  bool _sending = false;
  RequestSubmissionResult? _result;
  RequestSubmissionException? _submissionError;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(requestSubmissionRepositoryProvider);
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final result = await _repository.submit(widget.draft);
      if (mounted) setState(() => _result = result);
    } on RequestSubmissionException catch (error) {
      if (mounted) setState(() => _submissionError = error);
    } catch (e) {
      if (mounted) {
        setState(
          () => _submissionError = RequestSubmissionException(
            stage: RequestSubmissionStage.create,
            customMessage: e is ApiException ? e.message : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _SubmissionSuccess(result: _result!);
    if (_submissionError != null) {
      return _SubmissionError(error: _submissionError!);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('Revisa tu solicitud'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: _reviewBody(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: FilledButton(
                    key: const Key('submit-client-request'),
                    onPressed: _sending ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF14951F),
                    ),
                    child: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enviar solicitud'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Confirma los datos antes de enviar tu solicitud a los yonkes con cobertura en tu ciudad.',
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: const Color(0xFF30394B)),
      ),
      const SizedBox(height: 20),
      _ReviewCard(
        title: 'Información de la pieza',
        children: [
          _ReviewRow('Pieza', widget.draft.part),
          _ReviewRow('Marca', widget.draft.brandName ?? '—'),
          _ReviewRow('Modelo', widget.draft.modelName ?? '—'),
          _ReviewRow('Año', widget.draft.year?.toString() ?? '—'),
          if (widget.draft.description != null)
            _ReviewRow('Descripción', widget.draft.description!),
        ],
      ),
      const SizedBox(height: 16),
      _ReviewCard(
        title: 'Ciudad de envío',
        children: [_ReviewRow('Ciudad', widget.draft.cityName ?? '—')],
      ),
      const SizedBox(height: 16),
      _ReviewCard(
        title: 'Fotografías (${widget.draft.photos.length})',
        children: [
          if (widget.draft.photos.isEmpty)
            const Text(
              'No agregaste fotografías.',
              style: TextStyle(color: Color(0xFF596276)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.draft.photos.length,
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  widget.draft.photos[index].bytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _SubmissionSuccess extends StatelessWidget {
  const _SubmissionSuccess({required this.result});
  final RequestSubmissionResult result;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.send_rounded,
                  size: 76,
                  color: Color(0xFF14951F),
                ),
                const SizedBox(height: 18),
                Text(
                  'Solicitud enviada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Los yonkes con cobertura en tu ciudad podrán revisar tu solicitud y enviarte cotizaciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF596276)),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.clientRequests),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF14951F),
                  ),
                  child: const Text('Ver mis solicitudes'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.clientHome),
                  child: const Text('Ir al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SubmissionError extends StatelessWidget {
  const _SubmissionError({required this.error});
  final RequestSubmissionException error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Color(0xFFB3261E),
              ),
              const SizedBox(height: 16),
              Text(
                'No se completó el envío',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(error.message, textAlign: TextAlign.center),
              if (error.message.toLowerCase().contains('límite') ||
                  error.message.toLowerCase().contains('limite')) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Límite diario alcanzado',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'La API permite registrar un máximo de 3 solicitudes por día. '
                        'Puedes entrar a "Mis solicitudes" para ver o cancelar solicitudes previas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.clientRequests),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ver mis solicitudes'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.clientHome),
                  child: const Text('Ir al inicio'),
                ),
              ] else ...[
                if (error.requestId != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'No reintentes desde esta pantalla para evitar crear una solicitud duplicada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF596276), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.clientHome),
                  child: const Text('Ir al inicio'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE0E4EA)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF596276), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
