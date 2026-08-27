import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    required this.title,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No fue posible abrir el documento.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final content = snapshot.data!;
          return SelectionArea(
            child: ListView(
              key: const Key('legal_document_content'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                SelectableText(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.45),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
