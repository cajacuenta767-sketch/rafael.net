import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/app/theme/app_theme.dart';
import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_exception.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/home/presentation/start_page.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_register_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_forgot_password_page.dart';
import 'package:app_yonke/features/requests/presentation/new_request_page.dart';
import 'package:app_yonke/features/requests/presentation/request_review_page.dart';
import 'package:app_yonke/features/requests/presentation/my_requests_page.dart';
import 'package:app_yonke/features/requests/presentation/request_detail_page.dart';
import 'package:app_yonke/features/requests/domain/request_draft.dart';
import 'package:app_yonke/features/quotes/presentation/client_quotes_page.dart';
import 'package:app_yonke/features/quotes/presentation/quote_detail_page.dart';
import 'package:app_yonke/features/quotes/domain/client_quote.dart';
import 'package:app_yonke/features/quotes/data/quote_yonke_resolver.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/yonkes/data/yonkes_api.dart';
import 'package:app_yonke/features/messages/presentation/client_conversation_page.dart';
import 'package:app_yonke/features/orders/presentation/client_order_pages.dart';
import 'package:app_yonke/features/orders/domain/client_order_creation.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/profile/presentation/client_profile_page.dart';
import 'package:app_yonke/features/profile/presentation/client_onboarding_page.dart';
import 'package:app_yonke/features/ratings/presentation/client_rating_page.dart';
import 'package:app_yonke/features/notifications/presentation/client_notifications_page.dart';
import 'package:app_yonke/features/yonkes/presentation/client_yonkes_page.dart';
import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_requests_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_request_detail_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_quote_page.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_detail.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quotes_page.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quote_detail_page.dart';
import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_profile/presentation/yonke_profile_page.dart';
import 'package:app_yonke/features/yonke_coverage/presentation/yonke_coverage_page.dart';
import 'package:app_yonke/features/yonke_notifications/presentation/yonke_notifications_page.dart';

import 'support/responsive_windows.dart';

// Captures the existing Flutter screens with isolated, illustrative API data.
// It never sends requests to Azure or changes production records.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('GalleryFont');
    font.addFont(
      File('C:/Windows/Fonts/arial.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        'C:/Users/PC/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await icons.load();
    FlutterSecureStorage.setMockInitialValues({});
    if (const String.fromEnvironment('GALLERY_CONTENT') == 'photos') {
      final urls = <Map<String, String>>[];
      for (final size in [
        const Size(160, 300),
        const Size(240, 240),
        const Size(400, 200),
        const Size(700, 100),
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFEAF2FA),
        );
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.shortestSide * .3,
          Paint()..color = const Color(0xFF1D55A3),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = data!.buffer.asUint8List();
        _fixturePhotos.add(
          RequestPhoto(
            file: XFile.fromData(
              bytes,
              name: 'fixture_${urls.length}.png',
              mimeType: 'image/png',
            ),
            bytes: bytes,
          ),
        );
        urls.add({
          'guidId': 'photo${urls.length}',
          'urlImagen': 'data:image/png;base64,${base64Encode(bytes)}',
        });
        image.dispose();
        picture.dispose();
      }
      _request['solicitudesImagenes'] = urls;
      _quote['solicitudCotizacionesImagenes'] = urls;
    }
  });
  final profile = _Profile();
  final quote = clientQuoteFromJson(_quote)!;
  final yonkeQuote = yonkeQuoteFromJson(_quote)!;
  final screens = <String, Widget Function()>{
    '00_bienvenida': () => const StartPage(),
    '01_cliente_acceso': () =>
        const ClientLoginPage(initialLegalAccepted: true),
    '02_cliente_inicio': () => const RoleHomePage.client(),
    '03_cliente_solicitud_pieza_vehiculo': () =>
        NewRequestPage(draft: _draft(), initialStep: 0),
    '04_cliente_solicitud_detalles': () =>
        NewRequestPage(draft: _draft(), initialStep: 1),
    '05_cliente_solicitud_fotos': () =>
        NewRequestPage(draft: _draft(), initialStep: 2),
    '06_cliente_solicitud_ciudad': () =>
        NewRequestPage(draft: _draft(), initialStep: 3),
    '07_cliente_solicitud_revision': () => RequestReviewPage(draft: _draft()),
    '08_cliente_solicitudes': () => const MyRequestsPage(),
    '09_cliente_detalle_solicitud': () =>
        const RequestDetailPage(requestId: 'r1'),
    '10_cliente_cotizaciones': () => const ClientQuotesPage(),
    '11_cliente_detalle_cotizacion': () =>
        QuoteDetailPage(quoteId: 'q1', initialQuote: quote),
    '12_cliente_aceptar': () => ClientOrderConfirmationPage(
      args: ClientOrderConfirmationArgs(quote: quote),
    ),
    '13_cliente_orden_creada': () => ClientOrderSuccessPage(
      args: ClientOrderSuccessArgs(
        quote: quote,
        result: const ClientOrderCreationResult(
          orderId: 'ord1',
          responseContractPending: false,
        ),
      ),
    ),
    '14_cliente_seguimiento': () => ClientOrderTrackingPage(
      args: ClientOrderTrackingArgs(quote: quote, orderId: 'ord1'),
    ),
    '15_cliente_mensajes': () => const ClientMessagesPage(),
    '16_cliente_chat': () =>
        ClientConversationPage(args: ClientConversationArgs(quote: quote)),
    '17_cliente_explorar_yonkes': () => const ClientYonkesPage(),
    '18_cliente_notificaciones': () => const ClientNotificationsPage(),
    '19_cliente_perfil': () => ClientProfilePage(repository: profile),
    '20_cliente_editar_perfil': () =>
        ClientOnboardingPage(editing: true, repository: profile),
    '21_cliente_direcciones': () => ClientAddressesPage(repository: profile),
    '22_cliente_metodos_pago': () => const ClientPaymentMethodsPage(),
    '23_cliente_ayuda': () => const ClientHelpPage(),
    '24_cliente_calificar': () =>
        ClientRatingPage(args: ClientRatingArgs(quote: quote)),
    '25_yonke_acceso': () => const YonkeLoginPage(),
    '26_yonke_registro': () => const YonkeRegisterPage(),
    '27_yonke_recuperar_contrasena': () => const YonkeForgotPasswordPage(),
    '28_yonke_inicio': () => const YonkeHomePage(),
    '29_yonke_solicitudes': () => const YonkeRequestsPage(),
    '30_yonke_detalle_solicitud': () => YonkeRequestDetailPage(
      requestYonkeId: 'a1',
      request: YonkeRequestSummary(
        requestId: 'r1',
        requestYonkeId: 'a1',
        part: 'Alternador',
        status: YonkeRequestStatus.newRequest,
        receivedAt: nullDate,
        brand: 'Nissan',
        model: 'Sentra',
        year: 2018,
      ),
    ),
    '31_yonke_nueva_cotizacion': () => const YonkeQuotePage(
      requestYonkeId: 'a1',
      detail: YonkeRequestDetail(
        requestId: 'r1',
        requestYonkeId: 'a1',
        part: 'Alternador',
        status: YonkeRequestStatus.newRequest,
        imageUrls: [],
        brand: 'Nissan',
        model: 'Sentra',
        year: 2018,
        city: 'Nogales, Sonora',
        description: 'Alternador usado, original y probado.',
      ),
    ),
    '32_yonke_cotizaciones': () => const YonkeQuotesPage(),
    '33_yonke_detalle_cotizacion': () =>
        YonkeQuoteDetailPage(quoteId: 'q1', initialQuote: yonkeQuote),
    '34_yonke_mensajes': () => const YonkeMessagesPage(),
    '35_yonke_chat': () =>
        YonkeConversationPage(args: YonkeConversationArgs(quote: yonkeQuote)),
    '36_yonke_perfil': () => const YonkeProfilePage(),
    '37_yonke_cobertura': () => const YonkeCoveragePage(yonkeId: 'y1'),
    '38_yonke_notificaciones': () =>
        const YonkeNotificationsPage(yonkeId: 'y1'),
  };
  const matrix = bool.fromEnvironment('GALLERY_MATRIX');
  const configuredWidth = int.fromEnvironment(
    'GALLERY_WIDTH',
    defaultValue: 430,
  );
  const configuredHeight = int.fromEnvironment(
    'GALLERY_HEIGHT',
    defaultValue: 932,
  );
  const boundaries = bool.fromEnvironment('GALLERY_BOUNDARIES');
  const devices = bool.fromEnvironment('GALLERY_DEVICES');
  // Representative viewports, not claims of exact hardware/browser behavior.
  // A high-resolution panel is not a 2880-wide logical phone viewport.
  final deviceProfiles = <({String name, Size size, double dpr})>[
    (name: 'celular_compacto', size: const Size(360, 640), dpr: 3),
    (name: 'celular_compacto_horizontal', size: const Size(640, 360), dpr: 3),
    (name: 'celular_grande', size: const Size(430, 932), dpr: 3),
    (name: 'celular_grande_horizontal', size: const Size(932, 430), dpr: 3),
    (name: 'tablet', size: const Size(800, 1280), dpr: 2),
    (name: 'tablet_horizontal', size: const Size(1280, 800), dpr: 2),
    (name: 'tablet_alta_resolucion', size: const Size(960, 1706), dpr: 3),
    (
      name: 'tablet_alta_resolucion_horizontal',
      size: const Size(1706, 960),
      dpr: 3,
    ),
    (name: 'laptop', size: const Size(1366, 768), dpr: 1),
    (name: 'escritorio', size: const Size(1600, 900), dpr: 1),
    (name: 'monitor_4k_escala_200', size: const Size(1920, 1080), dpr: 2),
    (name: 'monitor_ultrawide', size: const Size(2560, 1080), dpr: 1),
  ];
  final windows = boundaries
      ? [
          for (final width in [
            319,
            320,
            321,
            599,
            600,
            601,
            799,
            800,
            801,
            839,
            840,
            841,
            959,
            960,
            961,
            1199,
            1200,
            1201,
            1599,
            1600,
            1601,
          ])
            Size(width.toDouble(), 800),
          for (final height in [
            239,
            240,
            241,
            319,
            320,
            321,
            359,
            360,
            361,
            479,
            480,
            481,
            599,
            600,
            601,
            719,
            720,
            721,
          ])
            Size(600, height.toDouble()),
          for (final fraction in [.25, .33, .5, .67, .75])
            Size(1024 * fraction - 8, 768),
          const Size(360, 1024),
          const Size(512, 1024),
        ]
      : devices
      ? deviceProfiles.map((profile) => profile.size).toList()
      : matrix
      ? responsiveWindows
      : [Size(configuredWidth.toDouble(), configuredHeight.toDouble())];
  for (final window
      in windows
          .skip(const int.fromEnvironment('GALLERY_START'))
          .take(
            const int.fromEnvironment('GALLERY_TAKE', defaultValue: 9999),
          )) {
    final profileId = '${window.width.toInt()}x${window.height.toInt()}';
    for (final entry in screens.entries) {
      testWidgets('capture $profileId ${entry.key}', (tester) async {
        final scale = double.parse(
          const String.fromEnvironment('GALLERY_TEXT_SCALE', defaultValue: '1'),
        );
        // DPR changes physical pixels without changing the logical viewport.
        final device = devices
            ? deviceProfiles.firstWhere((profile) => profile.size == window)
            : null;
        final pixelRatio =
            device?.dpr ??
            double.parse(
              const String.fromEnvironment('GALLERY_DPR', defaultValue: '1'),
            );
        tester.view.physicalSize = window * pixelRatio;
        tester.view.devicePixelRatio = pixelRatio;
        const safe = String.fromEnvironment('GALLERY_SAFE');
        if (safe.isNotEmpty) {
          tester.view.padding = FakeViewPadding(
            top: 30 * pixelRatio,
            bottom: 20 * pixelRatio,
            left: safe == 'left' ? 36 * pixelRatio : 0,
            right: safe == 'right' ? 36 * pixelRatio : 0,
          );
          tester.view.viewPadding = tester.view.padding;
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(
                _Api(yonke: entry.key.contains('_yonke_')),
              ),
              tokenStoreProvider.overrideWithValue(_Tokens()),
              clientProfileRepositoryProvider.overrideWithValue(profile),
              quoteYonkeResolverProvider.overrideWithValue(_Resolver()),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => RepaintBoundary(
                key: key,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              theme: AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(
                  fontFamily: 'GalleryFont',
                ),
                primaryTextTheme: AppTheme.light.primaryTextTheme.apply(
                  fontFamily: 'GalleryFont',
                ),
              ),
              home: entry.value(),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 8),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        final prefix = devices
            ? '${device!.name}_${profileId}_dpr$pixelRatio/'
            : matrix || boundaries
            ? '$profileId/'
            : '';
        await _capture(tester, key, '$prefix${entry.key}');
        final scroll = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.down ||
                  widget.axisDirection == AxisDirection.up),
        );
        for (var index = 0; index < scroll.evaluate().length; index++) {
          final state = tester.state<ScrollableState>(scroll.at(index));
          final position = state.position;
          if (!position.hasContentDimensions ||
              position.viewportDimension <= 0) {
            continue;
          }
          var page = 0;
          while (position.pixels < position.maxScrollExtent - 1 && page < 20) {
            position.jumpTo(
              (position.pixels + position.viewportDimension * .75).clamp(
                0,
                position.maxScrollExtent,
              ),
            );
            // Build newly visible lazy children before allowing their async
            // resource requests to finish outside the fake test clock.
            for (var resourceFrame = 0; resourceFrame < 3; resourceFrame++) {
              await tester.pump(const Duration(milliseconds: 100));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 30)),
              );
            }
            // A lazy ListView can retain an offscreen loading animation in
            // its cache. Settling every ticker would wait forever although
            // the visible viewport is ready. Check the visible UI instead.
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              find.byType(CircularProgressIndicator).hitTestable(),
              findsNothing,
              reason:
                  'A visible request must finish before capturing $profileId ${entry.key}',
            );
            await _capture(
              tester,
              key,
              '$prefix${entry.key}_scroll${index}_${++page}',
            );
          }
        }
        const extras = bool.fromEnvironment('GALLERY_EXTRA_STATES');
        if (extras) {
          for (final element in scroll.evaluate()) {
            final position =
                (element as StatefulElement).state as ScrollableState;
            if (position.position.hasContentDimensions) {
              position.position.jumpTo(0);
            }
          }
          await tester.pumpAndSettle();
          final controllersBefore = tester
              .widgetList<EditableText>(find.byType(EditableText))
              .map((field) => field.controller)
              .toList();
          final fieldsBefore = controllersBefore
              .map((controller) => controller.text)
              .toList();
          tester.view.physicalSize =
              Size(window.height, window.width) * pixelRatio;
          await tester.pumpAndSettle();
          // Rotation can reveal lazily built fields; compare existing values,
          // not the number of currently visible editable widgets.
          expect(
            controllersBefore.map((controller) => controller.text).toList(),
            fieldsBefore,
          );
          await _capture(tester, key, '$prefix${entry.key}_rotacion');
          tester.view.physicalSize = window * pixelRatio;
          await tester.pumpAndSettle();
          if (fieldsBefore.isNotEmpty) {
            tester.view.viewInsets = FakeViewPadding(bottom: 240 * pixelRatio);
            await tester.pumpAndSettle();
            await _capture(tester, key, '$prefix${entry.key}_teclado_simulado');
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
          }
          if (entry.key == '02_cliente_inicio' ||
              entry.key == '28_yonke_inicio') {
            final action = find.bySemanticsLabel(
              entry.key.startsWith('02')
                  ? 'Abrir acciones rápidas'
                  : 'Abrir centro de cotizaciones',
            );
            await tester.tap(action.first);
            await tester.pumpAndSettle();
            await _capture(tester, key, '$prefix${entry.key}_acciones');
          }
          if (entry.key == '36_yonke_perfil') {
            await tester.tap(find.text('Información del negocio'));
            await tester.pumpAndSettle();
            await _capture(tester, key, '$prefix${entry.key}_editor');
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Métodos de contacto'));
            await tester.tap(find.text('Métodos de contacto'));
            await tester.pumpAndSettle();
            await _capture(tester, key, '$prefix${entry.key}_contacto');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}

final nullDate = DateTime(2026, 10, 2, 9, 30);
final _fixturePhotos = <RequestPhoto>[];

String _fixtureText(String normal, String long) =>
    const String.fromEnvironment('GALLERY_CONTENT') == 'long' ? long : normal;

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    const representative = bool.fromEnvironment('GALLERY_DEVICES');
    final outputScale = representative
        ? tester.view.devicePixelRatio.clamp(0.1, 2560 / boundary.size.width)
        : boundary.size.width > 1600
        ? 1600 / boundary.size.width
        : 1.0;
    final image = await boundary.toImage(pixelRatio: outputScale);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const folder = String.fromEnvironment(
      'GALLERY_FOLDER',
      defaultValue: 'build/app_gallery',
    );
    final file = File('$folder/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    final logical = boundary.size;
    final dpr = tester.view.devicePixelRatio;
    await File('$folder/$name.json').writeAsString(
      jsonEncode({
        'logicalWidth': logical.width,
        'logicalHeight': logical.height,
        'dpr': dpr,
        'textScale': double.parse(
          const String.fromEnvironment('GALLERY_TEXT_SCALE', defaultValue: '1'),
        ),
        'safeArea': const String.fromEnvironment('GALLERY_SAFE'),
        'physicalWidth': tester.view.physicalSize.width,
        'physicalHeight': tester.view.physicalSize.height,
        'captureWidth': image.width,
        'captureHeight': image.height,
        'captureScale': image.width / logical.width,
        'kind': const bool.fromEnvironment('GALLERY_DEVICES')
            ? 'representative'
            : 'stress',
      }),
    );
    image.dispose();
  });
}

RequestDraft _draft() => RequestDraft()
  ..photos.addAll(_fixturePhotos)
  ..part = 'Alternador'
  ..brandId = 1
  ..brandName = 'Nissan'
  ..modelId = 1
  ..modelName = 'Sentra'
  ..year = 2018
  ..engine = '1.8 L'
  ..transmission = 'Automática'
  ..description = 'Busco alternador original, usado y probado.'
  ..stateId = 26
  ..stateName = 'Sonora'
  ..cityId = 1
  ..cityName = 'Nogales';

final _request = <String, dynamic>{
  'guidId': 'r1',
  'marcaId': 1,
  'modeloId': 1,
  'marca': 'Nissan',
  'modelo': 'Sentra',
  'año': 2018,
  'piezaBuscada': _fixtureText(
    'Alternador',
    'Alternador original completo con arnés y regulador de voltaje para vehículo importado',
  ),
  'folio': 'SOL-001/2026',
  'fechaCreacion': '2026-10-02T09:30:00',
  'motor': '1.8 L',
  'transmicion': 'Automática',
  'descripcion': _fixtureText(
    'Alternador original, usado y probado.',
    List.filled(
      12,
      'Busco pieza original usada, probada, con sus conectores y garantía por escrito.',
    ).join(' '),
  ),
  'totalCotizaciones': 1,
  'cerrada': false,
  'estatusSolicitud': 'Activa',
  'estatusSolicitudId': 1,
  'usuarioId': 'c1',
  'marcas': {'marca': 'Nissan'},
  'modelos': {'modelo': 'Sentra'},
  'solicitudesImagenes': <dynamic>[],
};
final _yonke = <String, dynamic>{
  'guidId': 'y1',
  'nombre': _fixtureText(
    'Yonke El Profe',
    'Yonke El Profe y Autopartes Importadas del Norte de Sonora',
  ),
  'responsable': 'Noé Gámez',
  'telefono': '+526311234567',
  'correo': 'contacto@yonke.demo',
  'direccion': 'Av. Tecnológico 120',
  'cp': 84000,
  'ciudadId': 1,
  'ciudades': {
    'ciudad': 'Nogales',
    'entidades': {'entidad': 'Sonora'},
  },
  'promedio': 4.8,
  'totalCalificaciones': 24,
};
final _assignment = <String, dynamic>{
  'guidId': 'a1',
  'solicitudYonkeGuidId': 'a1',
  'solicitudGuidId': 'r1',
  'folio': 'SOL-001/2026',
  'piezaBuscada': _request['piezaBuscada'],
  'fechaEnvio': '2026-10-02T09:30:00',
  'fechaSolicitud': '2026-10-02T09:30:00',
  'vista': false,
  'estatus': 'Nueva',
  'estatusId': 1,
  'clienteGuidId': 'c1',
  'marca': 'Nissan',
  'modelo': 'Sentra',
  'año': 2018,
  'solicitudes': _request,
  'yonkeGuidId': 'y1',
  'yonkes': _yonke,
};
final _quote = <String, dynamic>{
  'guidId': 'q1',
  'yonkeGuidId': 'y1',
  'yonkeNombre': 'Yonke El Profe',
  'solicitudYonkeGuidId': 'a1',
  'solicitudGuidId': 'r1',
  'folio': 'SOL-001/2026',
  'piezaBuscada': _request['piezaBuscada'],
  'marca': 'Nissan',
  'modelo': 'Sentra',
  'anio': 2018,
  'precio': const String.fromEnvironment('GALLERY_CONTENT') == 'long'
      ? 185000000.99
      : 1850.0,
  'disponible': true,
  'esNueva': false,
  'activo': true,
  'tieneGarantia': true,
  'diasGarantia': 30,
  'envioDisponible': true,
  'costoEnvio': 150.0,
  'tiempoEntregaDias': 2,
  'comentarios': 'Pieza probada y lista para envío.',
  'fechaCreacion': '2026-10-02T10:00:00',
  'solicitudCotizacionEstatus': {'descripcion': 'Enviada'},
  'solicitudYonkes': _assignment,
  'solicitudCotizacionesImagenes': <dynamic>[],
};

class _Api implements ApiClient {
  _Api({required this.yonke});
  final bool yonke;
  dynamic _response(String path) {
    const content = String.fromEnvironment('GALLERY_CONTENT');
    if (content == 'error') {
      throw const ApiException(
        message: 'Sin conexión. Error simulado exclusivamente para pruebas.',
        statusCode: 503,
      );
    }
    Object? data = <dynamic>[];
    if (path.contains('mis-solicitudes')) {
      data = [_request];
    } else if (path.contains('mis-cotizaciones')) {
      data = [_quote];
    } else if (path.endsWith('/resumen')) {
      data = {'totalSolicitudes': 1, 'totalCotizaciones': 1};
    } else if (path.contains('mi-solicitud-reciente')) {
      data = _request;
    } else if (path.endsWith('/MisSolicitudes')) {
      data = [_assignment];
    } else if (path.endsWith('/MasReciente')) {
      data = _assignment;
    } else if (path.contains('TotalSolicitudesNuevas') ||
        path.endsWith('/Total')) {
      data = 1;
    } else if (path.contains('CotizacionYonke/')) {
      data = _quote;
    } else if (path.contains('SolicitudCotizacionMensajes')) {
      data = path.endsWith('/no-leidos')
          ? {'cantidad': 1}
          : [
              {
                'guidId': 'm1',
                'mensaje': 'Hola, ¿incluye garantía?',
                'tipoRemitenteId': 1,
                'usuarioId': 'c1',
                'fechaCreacion': '2026-10-02T10:31:00',
                'leido': true,
              },
              {
                'guidId': 'm2',
                'mensaje': 'Sí, está probado e incluye 30 días de garantía.',
                'tipoRemitenteId': 2,
                'usuarioId': 'y1',
                'fechaCreacion': '2026-10-02T10:32:00',
                'leido': false,
              },
            ];
    } else if (path.contains('/Orden/cotizacion/')) {
      data = null;
    } else if (path.contains('/Orden/')) {
      data = {
        'guidId': 'ord1',
        'cotizacionGuidId': 'q1',
        'estatus': 'Confirmada',
        'fechaCreacion': '2026-10-02T10:40:00',
        'puedeCancelar': true,
      };
    } else if (path.contains('/SolicitudesImagenes/')) {
      data = _request['solicitudesImagenes'];
    } else if (path.contains('/Solicitudes/')) {
      data = _request;
    } else if (path.contains('/destinatarios')) {
      data = [
        {
          'yonkeGuidId': 'y1',
          'nombre': 'Yonke El Profe',
          'yonkeNombre': 'Yonke El Profe',
          'telefono': '+526311234567',
          'vista': true,
        },
      ];
    } else if (path.contains('Calificaciones')) {
      data = {'promedio': 4.8, 'totalCalificaciones': 24};
    } else if (path.contains('/Yonkes/byPage')) {
      data = [_yonke];
    } else if (path.contains('/Yonkes/')) {
      data = _yonke;
    } else if (path.contains('/ClienteAuth/')) {
      data = {'nombre': 'Noé Gámez', 'telefono': '+526319990000'};
    } else if (path.endsWith('/marcas')) {
      data = [
        {'id': 1, 'marca': 'Nissan', 'activo': true},
      ];
    } else if (path.endsWith('/modelos')) {
      data = [
        {'id': 1, 'modelo': 'Sentra', 'marcaId': 1},
      ];
    } else if (path.endsWith('/entidades')) {
      data = [
        {'id': 26, 'entidad': 'Sonora', 'activo': true},
      ];
    } else if (path.endsWith('/ciudades')) {
      data = [
        {
          'id': 1,
          'ciudad': 'Nogales',
          'entidadId': 26,
          'entidades': {'entidad': 'Sonora'},
        },
      ];
    }
    if (content == 'empty' && data is List) data = <dynamic>[];
    return {'success': true, 'data': data, 'message': 'OK', 'statusCode': 200};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => _response(path);
  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _response(path);
  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _response(path);
  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => _response(path);
  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => _response(path);
}

class _Tokens implements TokenStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<String?> readYonkeGuidId() async => 'y1';
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {}
}

class _Profile implements ClientProfileRepository {
  static const profile = ClientProfile(
    id: 'c1',
    name: 'Noé Gámez',
    email: 'noe@ejemplo.com',
    phone: '+526319990000',
    city: 'Nogales, Sonora',
  );
  @override
  Future<ClientProfileSnapshot> load() async => const ClientProfileSnapshot(
    availability: ClientProfileAvailability.available,
    profile: profile,
  );
  @override
  Future<ClientProfile> draftForOnboarding() async => profile;
  @override
  Future<bool> needsOnboarding() async => false;
  @override
  Future<bool> readNotificationsEnabled() async => true;
  @override
  Future<List<ClientAddress>> loadAddresses() async => const [
    ClientAddress(
      label: 'Casa',
      street: 'Av. Tecnológico 120',
      city: 'Nogales, Sonora',
      postalCode: '84000',
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Resolver extends QuoteYonkeResolver {
  _Resolver()
    : super(QuotesApi(_Api(yonke: false)), YonkesApi(_Api(yonke: false)));
  @override
  Future<ClientQuote> resolve(ClientQuote quote) async => quote;
  @override
  Future<List<ClientQuote>> resolveAll(List<ClientQuote> quotes) async =>
      quotes;
}
