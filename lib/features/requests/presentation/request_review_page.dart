import 'package:flutter/material.dart';

import '../domain/request_draft.dart';

class RequestReviewPage extends StatelessWidget {
  const RequestReviewPage({super.key, required this.draft});

  final RequestDraft draft;

  void _showPendingApiMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La solicitud está lista. El envío real se activará cuando el inicio de sesión entregue una sesión válida de la API.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Confirma los datos antes de enviar tu solicitud a los yonkes.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF30394B)),
                        ),
                        const SizedBox(height: 20),
                        _ReviewCard(
                          title: 'Información de la pieza',
                          children: [
                            _ReviewRow('Pieza', draft.part),
                            _ReviewRow('Marca', draft.brandName ?? '—'),
                            _ReviewRow('Modelo', draft.modelName ?? '—'),
                            _ReviewRow('Año', draft.year?.toString() ?? '—'),
                            if (draft.description != null)
                              _ReviewRow('Descripción', draft.description!),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ReviewCard(
                          title: 'Ciudad de envío',
                          children: [
                            _ReviewRow('Ciudad', draft.cityName ?? '—'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ReviewCard(
                          title: 'Fotografías (${draft.photos.length})',
                          children: [
                            if (draft.photos.isEmpty)
                              const Text(
                                'No agregaste fotografías.',
                                style: TextStyle(color: Color(0xFF596276)),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: draft.photos.length,
                                itemBuilder: (context, index) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    draft.photos[index].bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'El envío real requiere una sesión válida de la API.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF596276),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => _showPendingApiMessage(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF14951F),
                        ),
                        child: const Text('Enviar solicitud'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
