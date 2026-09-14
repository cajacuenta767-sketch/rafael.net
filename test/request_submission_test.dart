import 'dart:typed_data';

import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/features/requests/data/request_submission_repository.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/requests/domain/request_submission.dart';
import 'package:app_yonke/features/requests/presentation/request_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/recording_api_client.dart';

void main() {
  group('ApiRequestSubmissionRepository (API real)', () {
    test('crea, verifica la ciudad, sube fotos y envía a los yonkes', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) =>
            RecordingApiClient.ok({'guidId': 'req-1', 'folio': 'SOL-1'}),
        'GET /api/SolicitudCiudades/req-1/ciudades': (_) =>
            RecordingApiClient.ok({
              'solicitudHeader': {
                'ciudadesSaveBySolicitud': [
                  {'ciudadId': 1, 'ciudad': 'Nogales'},
                ],
              },
            }),
        'POST /api/SolicitudesImagenes/req-1': (_) =>
            RecordingApiClient.ok(const []),
        'POST /api/SolicitudYonkes/req-1/enviar': (_) => RecordingApiClient.ok([
          {'guidId': 'asig-1', 'yonkeGuidId': 'y-1'},
          {'guidId': 'asig-2', 'yonkeGuidId': 'y-2'},
        ], message: 'Solicitud enviada'),
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      final result = await repository.submit(_draft(withPhoto: true));

      expect(result.requestId, 'req-1');
      expect(result.notifiedYonkes, 2);
      expect(result.reachedNoYonke, isFalse);
      expect(api.trace, [
        'POST /api/Solicitudes',
        'GET /api/SolicitudCiudades/req-1/ciudades',
        'POST /api/SolicitudesImagenes/req-1',
        'POST /api/SolicitudYonkes/req-1/enviar',
      ]);

      final body = api.callsTo('/api/Solicitudes').single.data as Map;
      expect(body['ciudadesIds'], [1]);
      expect(body['marcaId'], 1);
      expect(body['modeloId'], 7);
      expect(body['año'], 2018);
      expect(body['piezaBuscada'], 'Alternador');
      expect(body['descripcion'], 'Con polea');
      // El usuario lo identifica el token: nunca se inventa un usuarioId.
      expect(body.containsKey('usuarioId'), isFalse);

      final upload = api.callsTo('/api/SolicitudesImagenes/req-1').single;
      expect(upload.files.single.fieldName, 'imagenes');
      expect(upload.files.single.fileName, 'foto.jpg');
    });

    test('agrega la ciudad si el servidor no la asoció al crear', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) => RecordingApiClient.ok({'guidId': 'r'}),
        'GET /api/SolicitudCiudades/r/ciudades': (_) =>
            RecordingApiClient.ok(const []),
        'POST /api/SolicitudCiudades/r/ciudades': (_) =>
            RecordingApiClient.ok('ok'),
        'POST /api/SolicitudYonkes/r/enviar': (_) =>
            RecordingApiClient.ok({'yonkesNotificados': 1}),
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      final result = await repository.submit(_draft());

      expect(result.notifiedYonkes, 1);
      expect(api.callsTo('/api/SolicitudCiudades/r/ciudades').last.data, [1]);
      expect(api.trace, [
        'POST /api/Solicitudes',
        'GET /api/SolicitudCiudades/r/ciudades',
        'POST /api/SolicitudCiudades/r/ciudades',
        'POST /api/SolicitudYonkes/r/enviar',
      ]);
    });

    test('informa que ningún yonke tiene cobertura', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) => RecordingApiClient.ok({'guidId': 'r'}),
        'GET /api/SolicitudCiudades/r/ciudades': (_) => RecordingApiClient.ok([
          {'ciudadId': 1},
        ]),
        'POST /api/SolicitudYonkes/r/enviar': (_) =>
            RecordingApiClient.ok(const []),
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      final result = await repository.submit(_draft());

      expect(result.notifiedYonkes, 0);
      expect(result.reachedNoYonke, isTrue);
    });

    test('da por enviada la solicitud cuando enviar responde 500 '
        '(despacho automático al crear)', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) =>
            RecordingApiClient.ok('e3316a72-82e7-41c5-ac2c-fc12ced3965e'),
        'GET /api/SolicitudCiudades/e3316a72-82e7-41c5-ac2c-fc12ced3965e/ciudades':
            (_) => RecordingApiClient.ok([
              {'ciudadId': 1},
            ]),
        'POST /api/SolicitudYonkes/e3316a72-82e7-41c5-ac2c-fc12ced3965e/enviar':
            (_) => const ApiException(
              message: 'Error interno del servidor',
              statusCode: 500,
            ),
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      final result = await repository.submit(_draft());

      expect(result.requestId, 'e3316a72-82e7-41c5-ac2c-fc12ced3965e');
      expect(result.notifiedYonkes, isNull);
      expect(result.dispatchMessage, autoDispatchNotice);
    });

    test('no reporta éxito cuando enviar a yonkes falla', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) => RecordingApiClient.ok({'guidId': 'r'}),
        'GET /api/SolicitudCiudades/r/ciudades': (_) => RecordingApiClient.ok([
          {'ciudadId': 1},
        ]),
        'POST /api/SolicitudYonkes/r/enviar': (_) => const ApiException(
          message: 'La solicitud no tiene ciudades asociadas',
          statusCode: 400,
        ),
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      await expectLater(
        repository.submit(_draft()),
        throwsA(
          isA<RequestSubmissionException>()
              .having((e) => e.stage, 'stage', RequestSubmissionStage.dispatch)
              .having((e) => e.requestId, 'requestId', 'r')
              .having(
                (e) => e.message,
                'message',
                'La solicitud no tiene ciudades asociadas',
              ),
        ),
      );
    });

    test('propaga el rechazo del servidor aunque responda HTTP 200', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) => {
          'success': false,
          'message': 'Se alcanzó el límite de 3 solicitudes por día',
          'data': null,
          'statusCode': 400,
        },
      });
      final repository = ApiRequestSubmissionRepository(RequestsApi(api));

      await expectLater(
        repository.submit(_draft()),
        throwsA(
          isA<RequestSubmissionException>()
              .having((e) => e.stage, 'stage', RequestSubmissionStage.create)
              .having((e) => e.message, 'message', contains('límite')),
        ),
      );
      expect(api.trace, ['POST /api/Solicitudes']);
    });

    test('no sube fotos ni envía si el servidor no devuelve el guid', () async {
      final apiWithoutId = RecordingApiClient({
        'POST /api/Solicitudes': (_) => RecordingApiClient.ok(null),
      });
      await expectLater(
        ApiRequestSubmissionRepository(RequestsApi(apiWithoutId))
            .submit(_draft()),
        throwsA(
          isA<RequestSubmissionException>().having(
            (e) => e.stage,
            'stage',
            RequestSubmissionStage.requestId,
          ),
        ),
      );
      expect(apiWithoutId.trace, ['POST /api/Solicitudes']);
    });
  });

  group('requestIdFromCreateResponse', () {
    const guid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

    test('usa el guid aunque venga un id numérico primero', () {
      expect(
        requestIdFromCreateResponse({
          'data': {'id': 57, 'guidId': guid},
        }),
        guid,
      );
    });

    test('nunca devuelve un id numérico', () {
      expect(
        requestIdFromCreateResponse({
          'data': {'id': 57, 'folio': 'SOL-57'},
        }),
        isNull,
      );
    });

    test('encuentra el guid en objetos anidados y en texto plano', () {
      expect(
        requestIdFromCreateResponse({
          'data': {
            'id': 57,
            'solicitud': {'id': 57, 'guidId': guid},
          },
        }),
        guid,
      );
      expect(requestIdFromCreateResponse({'data': guid}), guid);
      expect(requestIdFromCreateResponse('  $guid '), guid);
    });

    test('la falta de guid se reporta con las claves recibidas', () async {
      final api = RecordingApiClient({
        'POST /api/Solicitudes': (_) =>
            RecordingApiClient.ok({'id': 57, 'folio': 'SOL-57'}),
      });
      await expectLater(
        ApiRequestSubmissionRepository(RequestsApi(api)).submit(_draft()),
        throwsA(
          isA<RequestSubmissionException>()
              .having((e) => e.stage, 'stage', RequestSubmissionStage.requestId)
              .having((e) => e.message, 'message', contains('id, folio')),
        ),
      );
      expect(api.trace, ['POST /api/Solicitudes']);
    });
  });

  group('notifiedYonkesFromResponse', () {
    test('reconoce listas, números, contadores y texto', () {
      expect(notifiedYonkesFromResponse(RecordingApiClient.ok([1, 2, 3])), 3);
      expect(notifiedYonkesFromResponse(RecordingApiClient.ok(4)), 4);
      expect(
        notifiedYonkesFromResponse(RecordingApiClient.ok({'total': 2})),
        2,
      );
      expect(
        notifiedYonkesFromResponse(
          RecordingApiClient.ok(null, message: 'Enviada a 5 yonkes'),
        ),
        5,
      );
      expect(notifiedYonkesFromResponse(RecordingApiClient.ok('ok')), isNull);
      expect(notifiedYonkesFromResponse(null), isNull);
    });
  });

  group('RequestReviewPage', () {
    testWidgets('cliente envía una solicitud a yonkes con cobertura', (
      tester,
    ) async {
      final draft = RequestDraft()
        ..part = 'Alternador'
        ..brandId = 1
        ..brandName = 'Nissan'
        ..modelId = 1
        ..modelName = 'Altima'
        ..year = 2018
        ..cityId = 1
        ..cityName = 'Nogales, Sonora';
      final repository = _RecordingSubmissionRepository();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(draft: draft, repository: repository),
          ),
        ),
      );

      expect(find.text('Enviar solicitud'), findsOneWidget);
      await tester.tap(find.byKey(const Key('submit-client-request')));
      await tester.pumpAndSettle();

      expect(repository.submitted.single.part, 'Alternador');
      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.textContaining('yonkes con cobertura en tu ciudad'),
        findsOneWidget,
      );
    });

    testWidgets('muestra a cuántos yonkes llegó la solicitud', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(
              draft: _draft(),
              repository: const _FixedSubmissionRepository(
                RequestSubmissionResult(requestId: 'r', notifiedYonkes: 3),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('submit-client-request')));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(find.textContaining('Se envió a 3 yonkes'), findsOneWidget);
    });

    testWidgets('avisa cuando ningún yonke tiene cobertura', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(
              draft: _draft(),
              repository: const _FixedSubmissionRepository(
                RequestSubmissionResult(requestId: 'r', notifiedYonkes: 0),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('submit-client-request')));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud registrada'), findsOneWidget);
      expect(
        find.textContaining('Todavía no hay yonkes con cobertura'),
        findsOneWidget,
      );
    });

    testWidgets('explica en qué paso falló el envío', (tester) async {
      final draft = RequestDraft()
        ..part = 'Radiador'
        ..brandId = 1
        ..modelId = 2
        ..year = 2020
        ..cityId = 1;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(
              draft: draft,
              repository: const _FailingSubmissionRepository(
                RequestSubmissionStage.dispatch,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('submit-client-request')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no se pudo enviar a los yonkes de cobertura'),
        findsOneWidget,
      );
    });

    testWidgets('reintenta desde el paso fallido sin duplicar la solicitud', (
      tester,
    ) async {
      final draft = RequestDraft()
        ..part = 'Radiador'
        ..brandId = 1
        ..modelId = 2
        ..year = 2020
        ..cityId = 1;
      final repository = _ResumableSubmissionRepository();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(draft: draft, repository: repository),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('submit-client-request')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry-client-request')), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry-client-request')));
      await tester.pumpAndSettle();

      expect(repository.submits, 1);
      expect(repository.resumes, 1);
      expect(repository.resumedStage, RequestSubmissionStage.dispatch);
      expect(find.byKey(const Key('retry-client-request')), findsNothing);
      expect(find.textContaining('2 yonke'), findsOneWidget);
    });

    testWidgets('envía todas las ciudades elegidas en la creación', (
      tester,
    ) async {
      final draft = RequestDraft()
        ..part = 'Radiador'
        ..brandId = 1
        ..modelId = 2
        ..year = 2020
        ..cityId = 1
        ..cityName = 'Nogales, Sonora'
        ..extraCityIds.add(7)
        ..extraCityNames.add('Hermosillo, Sonora');
      expect(draft.allCityIds, [1, 7]);
      expect(draft.citiesLabel, 'Nogales, Sonora, Hermosillo, Sonora');

      final repository = _RecordingSubmissionRepository();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RequestReviewPage(draft: draft, repository: repository),
          ),
        ),
      );
      expect(find.text('Ciudades'), findsOneWidget);
      expect(find.text('Nogales, Sonora, Hermosillo, Sonora'), findsOneWidget);
    });
  });
}

RequestDraft _draft({bool withPhoto = false}) {
  final draft = RequestDraft()
    ..part = 'Alternador'
    ..brandId = 1
    ..brandName = 'Nissan'
    ..modelId = 7
    ..modelName = 'Sentra'
    ..year = 2018
    ..description = 'Con polea'
    ..cityId = 1
    ..cityName = 'Nogales, Sonora';
  if (withPhoto) {
    // Los bytes viajan en `bytes`; la ruta solo aporta el nombre del archivo.
    draft.photos.add(
      RequestPhoto(
        file: XFile('/tmp/foto.jpg'),
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
  }
  return draft;
}

class _RecordingSubmissionRepository implements RequestSubmissionRepository {
  final submitted = <RequestDraft>[];

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) async {
    submitted.add(draft);
    return const RequestSubmissionResult(requestId: 'request-created');
  }

  @override
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  }) async => RequestSubmissionResult(requestId: requestId);
}

class _FixedSubmissionRepository implements RequestSubmissionRepository {
  const _FixedSubmissionRepository(this.result);

  final RequestSubmissionResult result;

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) async => result;

  @override
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  }) async => result;
}

class _FailingSubmissionRepository implements RequestSubmissionRepository {
  const _FailingSubmissionRepository(this.stage);

  final RequestSubmissionStage stage;

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) =>
      Future.error(RequestSubmissionException(stage: stage));

  @override
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  }) => Future.error(
    RequestSubmissionException(stage: stage, requestId: requestId),
  );
}

/// Falla una vez en el envío a yonkes y acepta el reintento sin volver a
/// crear la solicitud.
class _ResumableSubmissionRepository implements RequestSubmissionRepository {
  int submits = 0;
  int resumes = 0;
  RequestSubmissionStage? resumedStage;

  @override
  Future<RequestSubmissionResult> submit(RequestDraft draft) {
    submits++;
    return Future.error(
      const RequestSubmissionException(
        stage: RequestSubmissionStage.dispatch,
        requestId: 'request-created',
      ),
    );
  }

  @override
  Future<RequestSubmissionResult> resume(
    RequestDraft draft,
    String requestId, {
    required RequestSubmissionStage failedStage,
  }) async {
    resumes++;
    resumedStage = failedStage;
    return RequestSubmissionResult(requestId: requestId, notifiedYonkes: 2);
  }
}
