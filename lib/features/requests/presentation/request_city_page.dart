import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../domain/request_draft.dart';

class RequestCityPage extends StatefulWidget {
  const RequestCityPage({super.key, required this.draft});

  final RequestDraft draft;

  @override
  State<RequestCityPage> createState() => _RequestCityPageState();
}

class _RequestCityPageState extends State<RequestCityPage> {
  int? _selectedCityId;

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.draft.cityId;
  }

  void _continue() {
    final city = _temporaryCities.where((city) => city.id == _selectedCityId);
    if (city.isEmpty) return;
    widget.draft
      ..cityId = city.first.id
      ..cityName = city.first.name;

    context.push(AppRoutes.clientRequestReview, extra: widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedCityId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('Selecciona tu ciudad'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para enviar tu solicitud a los yonkes cercanos.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: const Color(0xFF30394B)),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _temporaryCities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final city = _temporaryCities[index];
                        final isSelected = city.id == _selectedCityId;
                        return Semantics(
                          button: true,
                          selected: isSelected,
                          label:
                              '${city.name}${isSelected ? ', seleccionada' : ''}',
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCityId = city.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              height: 64,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF15951F)
                                      : const Color(0xFFE0E4EA),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      city.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF202736),
                                      ),
                                    ),
                                  ),
                                  _SelectionCircle(selected: isSelected),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ciudades de prueba mientras se conecta el catálogo de la API.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF596276), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: canContinue ? _continue : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF14951F),
                      disabledBackgroundColor: const Color(0xFFB8CFBA),
                    ),
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? const Color(0xFF15951F) : const Color(0xFFBEC5CF),
        width: 2,
      ),
    ),
    child: selected
        ? const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF15951F),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          )
        : null,
  );
}

class _CityOption {
  const _CityOption(this.id, this.name);

  final int id;
  final String name;
}

// Datos temporales de interfaz. No representan IDs confirmados por la API.
const _temporaryCities = [
  _CityOption(1, 'Nogales, Sonora'),
  _CityOption(2, 'Hermosillo, Sonora'),
  _CityOption(3, 'Agua Prieta, Sonora'),
  _CityOption(4, 'Mexicali, Baja California'),
  _CityOption(5, 'Tijuana, Baja California'),
  _CityOption(6, 'Ciudad Juárez, Chihuahua'),
];
