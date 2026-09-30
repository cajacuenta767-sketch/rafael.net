import 'package:app_yonke/core/di/api_providers.dart';
import 'package:app_yonke/features/auth/presentation/client_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_login_page.dart';
import 'package:app_yonke/features/auth/presentation/yonke_register_page.dart';
import 'package:app_yonke/features/home/presentation/client_bottom_navigation.dart';
import 'package:app_yonke/features/home/presentation/role_home_page.dart';
import 'package:app_yonke/features/home/presentation/start_page.dart';
import 'package:app_yonke/features/profile/presentation/client_profile_page.dart';
import 'package:app_yonke/features/yonke_home/presentation/yonke_home_page.dart';
import 'package:app_yonke/features/yonke_messages/presentation/yonke_messages_page.dart';
import 'package:app_yonke/features/yonke_profile/presentation/yonke_profile_page.dart';
import 'package:app_yonke/features/yonke_quotes/presentation/yonke_quotes_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_bottom_navigation.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_request_detail_page.dart';
import 'package:app_yonke/features/yonke_requests/presentation/yonke_requests_page.dart';
import 'package:app_yonke/features/yonkes/presentation/client_yonkes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/arnes_responsivo.dart';
import '../support/dispositivos_prueba.dart';
import '../support/dobles_responsivos.dart';

enum RolPagina { comun, cliente, yonke }

/// Una pantalla de la app que la matriz responsive monta en cada dispositivo.
class PaginaPrueba {
  const PaginaPrueba({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.construir,
    this.overrides = _sinOverrides,
    this.textosClave = const [],
    this.llavesClave = const [],
    this.bottomNav,
  });

  /// Identificador corto (carpeta de capturas y clave de hallazgos).
  final String id;
  final String nombre;
  final RolPagina rol;
  final Widget Function() construir;
  final List<Override> Function() overrides;

  /// Textos que deben estar presentes (`find.textContaining`).
  final List<String> textosClave;

  /// Llaves de widgets que deben estar presentes.
  final List<Key> llavesClave;

  /// Tipo del widget de navegación inferior, si la página lo tiene; se
  /// verifica que quede completo dentro de la pantalla.
  final Type? bottomNav;

  static List<Override> _sinOverrides() => const [];
}

final paginasResponsivas = <PaginaPrueba>[
  PaginaPrueba(
    id: 'inicio',
    nombre: 'Inicio (elegir rol)',
    rol: RolPagina.comun,
    construir: () => const StartPage(),
    textosClave: const ['Soy cliente', 'Soy Yonke'],
  ),
  PaginaPrueba(
    id: 'cliente-login',
    nombre: 'Cliente: ingreso',
    rol: RolPagina.cliente,
    construir: () => const ClientLoginPage(initialLegalAccepted: true),
    overrides: () => [
      clientAuthRepositoryProvider.overrideWithValue(
        AuthClientePendienteDoble(),
      ),
      tokenStoreProvider.overrideWithValue(TokenStoreMemoriaDoble()),
    ],
    textosClave: const ['INGRESO PARA CLIENTES', 'Enviar código'],
    llavesClave: const [Key('client_phone_field')],
  ),
  PaginaPrueba(
    id: 'cliente-home',
    nombre: 'Cliente: inicio',
    rol: RolPagina.cliente,
    construir: () => const RoleHomePage.client(),
    overrides: () => [
      tokenStoreProvider.overrideWithValue(
        TokenStoreMemoriaDoble(accessToken: 'jwt'),
      ),
      apiClientProvider.overrideWithValue(ApiTableroClienteDoble()),
    ],
    textosClave: const ['Solicitudes recientes', 'Alternador'],
    bottomNav: ClientBottomNavigation,
  ),
  PaginaPrueba(
    id: 'cliente-perfil',
    nombre: 'Cliente: perfil',
    rol: RolPagina.cliente,
    construir: () => ClientProfilePage(
      repository: PerfilClienteDoble(),
      tokenStore: TokenStoreMemoriaDoble(accessToken: 'jwt'),
    ),
    textosClave: const ['Noe Gamez'],
    bottomNav: ClientBottomNavigation,
  ),
  PaginaPrueba(
    id: 'cliente-yonkes',
    nombre: 'Cliente: explorar yonkes',
    rol: RolPagina.cliente,
    construir: () => const ClientYonkesPage(repository: YonkesClienteDoble()),
    textosClave: const ['Yonke del Norte'],
    bottomNav: ClientBottomNavigation,
  ),
  PaginaPrueba(
    id: 'yonke-login',
    nombre: 'Yonke: ingreso',
    rol: RolPagina.yonke,
    construir: () => const YonkeLoginPage(),
    overrides: () => [
      yonkeAuthRepositoryProvider.overrideWithValue(AuthYonkePendienteDoble()),
    ],
    textosClave: const ['Ingreso para yonkes'],
    llavesClave: const [Key('yonke-login-button')],
  ),
  PaginaPrueba(
    id: 'yonke-registro',
    nombre: 'Yonke: registro',
    rol: RolPagina.yonke,
    construir: () => const YonkeRegisterPage(),
    overrides: () => [
      catalogsApiProvider.overrideWithValue(CatalogosApiDoble()),
      yonkesApiProvider.overrideWithValue(YonkesApiDoble()),
    ],
    llavesClave: const [Key('yonke-register-name')],
  ),
  PaginaPrueba(
    id: 'yonke-home',
    nombre: 'Yonke: inicio',
    rol: RolPagina.yonke,
    construir: () => YonkeHomePage(
      dataLoader: () async => YonkeHomeData(
        requests: solicitudesYonkeDemo,
        quoteCount: 14,
        unreadMessages: 5,
        businessName: 'Yonke El Profe',
      ),
    ),
    textosClave: const ['Yonke El Profe', 'Solicitudes recientes'],
    bottomNav: YonkeBottomNavigation,
  ),
  PaginaPrueba(
    id: 'yonke-solicitudes',
    nombre: 'Yonke: bandeja de solicitudes',
    rol: RolPagina.yonke,
    construir: () =>
        const YonkeRequestsPage(repository: SolicitudesYonkeDemoDoble()),
    textosClave: const ['Solicitudes recibidas'],
    bottomNav: YonkeBottomNavigation,
  ),
  PaginaPrueba(
    id: 'yonke-solicitud-detalle',
    nombre: 'Yonke: detalle de solicitud',
    rol: RolPagina.yonke,
    construir: () => YonkeRequestDetailPage(
      requestYonkeId: solicitudesYonkeDemo.first.requestYonkeId,
      request: solicitudesYonkeDemo.first,
      repository: const DetalleSolicitudYonkeDemoDoble(),
    ),
    textosClave: const ['Detalle de solicitud'],
    llavesClave: const [Key('yonke-quote-button')],
  ),
  PaginaPrueba(
    id: 'yonke-cotizaciones',
    nombre: 'Yonke: cotizaciones enviadas',
    rol: RolPagina.yonke,
    construir: () =>
        const YonkeQuotesPage(repository: CotizacionesYonkeDemoDoble()),
    textosClave: const ['Cotizaciones enviadas'],
    bottomNav: YonkeBottomNavigation,
  ),
  PaginaPrueba(
    id: 'yonke-mensajes',
    nombre: 'Yonke: mensajes',
    rol: RolPagina.yonke,
    construir: () => const YonkeMessagesPage(repository: MensajesYonkeDoble()),
    textosClave: const ['Carlos Mendoza'],
  ),
  PaginaPrueba(
    id: 'yonke-perfil',
    nombre: 'Yonke: perfil',
    rol: RolPagina.yonke,
    construir: () => YonkeProfilePage(
      repository: const PerfilYonkeDoble(),
      tokenStore: TokenStoreMemoriaDoble(
        accessToken: 'jwt',
        yonkeGuidId: 'yonke-guid-1',
      ),
    ),
    textosClave: const ['Yonke El Profe'],
  ),
];

/// Monta [pagina] en [dispositivo] y verifica: sin excepciones de layout,
/// textos y llaves clave presentes y navegación inferior dentro de pantalla.
Future<void> verificarPaginaEnDispositivo(
  WidgetTester tester,
  PaginaPrueba pagina,
  DispositivoPrueba dispositivo, {
  double escalaTexto = 1,
}) async {
  await pumpEnDispositivo(
    tester,
    dispositivo,
    pagina.construir(),
    escalaTexto: escalaTexto,
    overrides: pagina.overrides(),
  );
  expectSinExcepciones(tester, dispositivo);
  for (final texto in pagina.textosClave) {
    expect(
      find.textContaining(texto),
      findsWidgets,
      reason: '"$texto" no aparece en ${dispositivo.descripcion}',
    );
  }
  for (final llave in pagina.llavesClave) {
    expect(
      find.byKey(llave),
      findsOneWidget,
      reason: '$llave no aparece en ${dispositivo.descripcion}',
    );
  }
  if (pagina.bottomNav != null) {
    expectDentroDePantalla(tester, find.byType(pagina.bottomNav!), dispositivo);
  }
}
