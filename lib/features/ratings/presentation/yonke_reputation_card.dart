import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/api_providers.dart';
import '../data/yonke_reputation_repository.dart';
import '../domain/yonke_reputation.dart';

class YonkeReputationCard extends ConsumerStatefulWidget {
  const YonkeReputationCard({
    super.key,
    required this.yonkeId,
    required this.isDemo,
    this.repository,
  });

  final String yonkeId;
  final bool isDemo;
  final YonkeReputationRepository? repository;

  @override
  ConsumerState<YonkeReputationCard> createState() =>
      _YonkeReputationCardState();
}

class _YonkeReputationCardState extends ConsumerState<YonkeReputationCard> {
  late final YonkeReputationRepository _repository;
  YonkeReputation? _reputation;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (widget.isDemo
            ? const DemoYonkeReputationRepository()
            : ref.read(yonkeReputationRepositoryProvider));
    _load();
  }

  Future<void> _load() async {
    if (widget.yonkeId.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final reputation = await _repository.getReputation(widget.yonkeId);
      if (mounted) {
        setState(() {
          _reputation = reputation;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E6EC)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 54,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error) {
      return Row(
        children: [
          const Icon(Icons.star_outline, color: Color(0xFF596276)),
          const SizedBox(width: 10),
          const Expanded(child: Text('No se pudo cargar la reputación.')),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    }
    final reputation = _reputation!;
    if (reputation.count == 0) {
      return const Row(
        children: [
          Icon(Icons.star_outline, color: Color(0xFF596276)),
          SizedBox(width: 10),
          Expanded(child: Text('Este yonke aún no tiene calificaciones.')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF5AA16)),
            const SizedBox(width: 6),
            Text(
              reputation.average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              '${reputation.count} ${reputation.count == 1 ? 'calificación' : 'calificaciones'}',
              style: const TextStyle(color: Color(0xFF596276)),
            ),
          ],
        ),
        if (reputation.comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...reputation.comments.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('“${item.comment}”'),
            ),
          ),
        ],
      ],
    );
  }
}
