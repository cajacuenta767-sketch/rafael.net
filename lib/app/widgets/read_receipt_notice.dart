import 'package:flutter/material.dart';

class ReadReceiptNotice extends StatelessWidget {
  const ReadReceiptNotice({super.key, required this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          const Text('Lectura pendiente de sincronizar.'),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
