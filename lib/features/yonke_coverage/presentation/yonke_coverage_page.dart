import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/api_providers.dart';
import '../data/yonke_coverage_repository.dart';
import '../domain/yonke_coverage.dart';

class YonkeCoveragePage extends ConsumerStatefulWidget {
  const YonkeCoveragePage({super.key, this.yonkeId, this.repository});

  /// Identificador del yonke. Si no se indica, se lee el `yonkeGuidId` que
  /// guardó el inicio de sesión.
  final String? yonkeId;
  final YonkeCoverageRepository? repository;

  @override
  ConsumerState<YonkeCoveragePage> createState() => _YonkeCoveragePageState();
}

class _YonkeCoveragePageState extends ConsumerState<YonkeCoveragePage> {
  late final YonkeCoverageRepository _repository;
  YonkeCoverageSnapshot? _snapshot;
  Set<int> _selectedCityIds = {};
  bool _loading = true;
  bool _saving = false;
  bool _identityPending = false;
  Object? _error;
  String? _yonkeId;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ref.read(yonkeCoverageRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _identityPending = false;
      _error = null;
    });
    try {
      _yonkeId =
          widget.yonkeId ??
          await ref.read(tokenStoreProvider).readYonkeGuidId();
      final snapshot = await _repository.load(yonkeId: _yonkeId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedCityIds = {...snapshot.selectedCityIds};
        _loading = false;
      });
    } on YonkeIdentityContractPendingException {
      if (mounted) {
        setState(() {
          _identityPending = true;
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

  Future<void> _save() async {
    final yonkeId = _yonkeId;
    if (_saving ||
        _selectedCityIds.isEmpty ||
        yonkeId == null ||
        yonkeId.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.save(yonkeId: yonkeId, cityIds: _selectedCityIds);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cobertura guardada.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la cobertura.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFBFD),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFAFBFD),
      surfaceTintColor: const Color(0xFFFAFBFD),
      centerTitle: true,
      title: const Text('Ciudades de cobertura'),
      actions: [
        IconButton(
          tooltip: 'Actualizar ciudades',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(top: false, child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_identityPending) return const _IdentityPending();
    if (_error != null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar la cobertura',
        message: 'Revisa tu conexión e inténtalo nuevamente.',
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Reintentar'),
        ),
      );
    }
    final snapshot = _snapshot!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Text(
              'Define dónde atenderás solicitudes',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Recibirás solicitudes de refacciones enviadas a estas ciudades.',
              style: TextStyle(color: Color(0xFF596276)),
            ),
            const SizedBox(height: 18),
            ...snapshot.cities.map(_cityTile),
            const SizedBox(height: 8),
            if (_selectedCityIds.isEmpty)
              const Text(
                'Selecciona al menos una ciudad para guardar tu cobertura.',
                style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('yonke-save-coverage'),
              onPressed: _saving || _selectedCityIds.isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF114EB0),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar cobertura'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityTile(CoverageCity city) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE0E4EA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CheckboxListTile(
        key: Key('yonke-coverage-city-${city.id}'),
        value: _selectedCityIds.contains(city.id),
        activeColor: const Color(0xFF114EB0),
        title: Text(
          city.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(city.state),
        controlAffinity: ListTileControlAffinity.trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onChanged: _saving
            ? null
            : (selected) => setState(() {
                if (selected == true) {
                  _selectedCityIds.add(city.id);
                } else {
                  _selectedCityIds.remove(city.id);
                }
              }),
      ),
    ),
  );
}

class _IdentityPending extends StatelessWidget {
  const _IdentityPending();

  @override
  Widget build(BuildContext context) => const _StateCard(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Cobertura pendiente de conexión',
    message: 'La sesión no incluye el identificador del yonke (yonkeGuidId). Vuelve a iniciar sesión para administrar tu cobertura.',
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFF596276)),
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
    ),
  );
}
