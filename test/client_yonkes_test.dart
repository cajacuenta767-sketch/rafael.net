import 'package:app_yonke/features/yonkes/data/client_yonkes_repository.dart';
import 'package:app_yonke/features/yonkes/domain/client_yonke.dart';
import 'package:app_yonke/features/yonkes/presentation/client_yonkes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta la paginación, ubicación y calificaciones del API', () {
    final page = clientYonkePageFromResponse({
      'success': true,
      'data': {
        'data': [
          {
            'guidId': 'yonke-1',
            'nombre': 'Yonke del Norte',
            'ciudadId': 7,
            'ciudades': {
              'ciudad': 'Nogales',
              'entidades': {'entidad': 'Sonora'},
            },
            'yonkesCalificaciones': [
              {'calificacion': 5, 'activa': true},
              {'calificacion': 4, 'activa': true},
            ],
          },
        ],
        'meta': {'page': 1, 'pageCount': 3},
      },
    });

    expect(page.page, 1);
    expect(page.pageCount, 3);
    expect(page.hasMore, isTrue);
    expect(page.items.single.name, 'Yonke del Norte');
    expect(page.items.single.location, 'Nogales, Sonora');
    expect(page.items.single.ratingAverage, 4.5);
    expect(page.items.single.ratingCount, 2);
  });

  testWidgets('explorador busca y conserva el diseño de referencia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeClientYonkesRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ClientYonkesPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explorar yonkes'), findsOneWidget);
    expect(find.text('Yonke del Norte'), findsOneWidget);
    expect(find.text('4.8 (128)'), findsOneWidget);
    expect(find.text('Ver perfil'), findsNWidgets(4));
    await expectLater(
      find.byType(ClientYonkesPage),
      matchesGoldenFile('goldens/client_yonkes_reference.png'),
    );

    await tester.enterText(
      find.byKey(const Key('yonke-search-input')),
      'Frontera',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repository.lastSearch, 'Frontera');
  });

  testWidgets('perfil muestra información, cobertura y opiniones reales', (
    tester,
  ) async {
    final repository = _FakeClientYonkesRepository();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClientYonkeProfilePage(
            initial: _yonkes.first,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil del yonke'), findsOneWidget);
    expect(find.text('Nogales, Sonora'), findsWidgets);
    final review = find.textContaining(
      'Atención rápida y pieza en buen estado.',
    );
    await tester.scrollUntilVisible(
      review,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(review, findsOneWidget);
  });
}

const _yonkes = [
  ClientYonke(
    id: 'yonke-1',
    name: 'Yonke del Norte',
    cityId: 7,
    city: 'Nogales',
    state: 'Sonora',
    address: 'Av. Tecnológico 120',
    phone: '+52 631 000 0000',
    ratingAverage: 4.8,
    ratingCount: 128,
  ),
  ClientYonke(
    id: 'yonke-2',
    name: 'Yonke Frontera',
    cityId: 7,
    city: 'Nogales',
    state: 'Sonora',
    ratingAverage: 4.6,
    ratingCount: 95,
  ),
  ClientYonke(
    id: 'yonke-3',
    name: 'AutoPartes Linares',
    cityId: 7,
    city: 'Nogales',
    state: 'Sonora',
    ratingAverage: 4.7,
    ratingCount: 76,
  ),
  ClientYonke(
    id: 'yonke-4',
    name: 'Yonke La 20',
    cityId: 8,
    city: 'Santa Ana',
    state: 'Sonora',
    ratingAverage: 4.5,
    ratingCount: 63,
  ),
];

class _FakeClientYonkesRepository implements ClientYonkesRepository {
  String? lastSearch;

  @override
  Future<ClientYonkePage> getPage({
    required int page,
    required int pageSize,
    String? search,
    int? cityId,
  }) async {
    lastSearch = search;
    final query = search?.toLowerCase();
    return ClientYonkePage(
      items: _yonkes
          .where(
            (yonke) =>
                (query == null || yonke.name.toLowerCase().contains(query)) &&
                (cityId == null || yonke.cityId == cityId),
          )
          .toList(),
      page: 1,
      pageCount: 1,
    );
  }

  @override
  Future<List<ClientYonkeCity>> getCities() async => const [
    ClientYonkeCity(id: 7, name: 'Nogales', state: 'Sonora'),
    ClientYonkeCity(id: 8, name: 'Santa Ana', state: 'Sonora'),
  ];

  @override
  Future<ClientYonkeDetail> getDetail(ClientYonke initial) async =>
      ClientYonkeDetail(
        yonke: initial,
        ratingComments: const ['Atención rápida y pieza en buen estado.'],
        coverage: const ['Nogales, Sonora', 'Santa Ana, Sonora'],
      );
}
