import 'dart:convert';
import 'dart:io';

import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/dashboard/data/dashboard_api.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/requests/data/client_requests_memory.dart';
import 'package:app_yonke/features/requests/data/requests_api.dart';
import 'package:app_yonke/features/requests/domain/client_request.dart';
import 'package:app_yonke/features/yonke_quotes/data/yonke_quotes_repository.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(String sub, {String? email, String? name}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': sub, 'email': ?email, 'name': ?name, 'exp': 1893456000})}.fakeSignature';
}

class _TestTokenStore implements TokenStore {
  _TestTokenStore(this._token);
  String? _token;

  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<DateTime?> readExpiresAt() async => null;
  @override
  Future<String?> readYonkeGuidId() async => null;
  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    _token = accessToken;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

class _DummyApiClient implements ApiClient {
  _DummyApiClient([this._assignedResponse]);
  final dynamic _assignedResponse;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _assignedResponse ?? {'data': []};
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async => null;
  @override
  Future<dynamic> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async => null;
  @override
  Future<dynamic> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async => null;
  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => null;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Memoria de correo del cliente', () {
    test('guarda perfil por correo y lo reutiliza en sesiones futuras sin pedir onboarding', () async {
      final tokenStore1 = _TestTokenStore(_fakeJwt('sub-1', email: 'antiguo@refanet.mx'));
      final repo1 = LocalClientProfileRepository(
        tokenStore: tokenStore1,
        photosDirectory: () async => Directory.systemTemp.createTemp('profile_test'),
      );

      // El usuario guarda su perfil completo la primera vez
      await repo1.saveProfile(const ClientProfile(
        id: 'sub-1',
        name: 'Carlos Mendoza',
        phone: '+526629998877',
        email: 'antiguo@refanet.mx',
        city: 'Hermosillo, Sonora',
      ));

      // Simulamos que la app se actualiza o reinicia, y el usuario entra con un nuevo token
      // para el mismo correo (por ejemplo, sub-2 tras nuevo login de Google)
      final tokenStore2 = _TestTokenStore(_fakeJwt('sub-2', email: 'antiguo@refanet.mx'));
      final repo2 = LocalClientProfileRepository(
        tokenStore: tokenStore2,
        photosDirectory: () async => Directory.systemTemp.createTemp('profile_test'),
      );

      // Verificamos que needsOnboarding es false porque la memoria de correo tiene el perfil
      final needsOnboarding = await repo2.needsOnboarding();
      expect(needsOnboarding, isFalse);

      // Verificamos que load() recupera los datos guardados del correo
      final snapshot = await repo2.load();
      expect(snapshot.profile.name, 'Carlos Mendoza');
      expect(snapshot.profile.phone, '+526629998877');
      expect(snapshot.profile.email, 'antiguo@refanet.mx');
    });

    test('persistencia y fusión de solicitudes del cliente por correo', () async {
      final memory = ClientRequestsMemory();

      // Guardamos una solicitud antigua
      final reqAntigua = ClientRequestSummary(
        id: 'req-antigua-1',
        part: 'Transmisión automática',
        status: 'Cotizada',
        quoteCount: 2,
        brand: 'Ford',
        model: 'F-150',
        year: 2018,
        createdAt: DateTime(2026, 1, 10),
      );
      await memory.saveRequests('cliente@correo.com', [reqAntigua]);

      // Al cargar, está presente
      var loaded = await memory.loadRequests('cliente@correo.com');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'req-antigua-1');

      // Se agrega una nueva solicitud
      final reqNueva = ClientRequestSummary(
        id: 'req-nueva-2',
        part: 'Faro izquierdo',
        status: 'En proceso',
        quoteCount: 0,
        brand: 'Nissan',
        model: 'Sentra',
        year: 2020,
        createdAt: DateTime(2026, 2, 1),
      );
      await memory.addSingleRequest('cliente@correo.com', reqNueva);

      // La memoria conserva AMBAS solicitudes
      loaded = await memory.loadRequests('cliente@correo.com');
      expect(loaded.length, 2);
      expect(loaded.any((r) => r.id == 'req-antigua-1'), isTrue);
      expect(loaded.any((r) => r.id == 'req-nueva-2'), isTrue);
    });
  });

  group('Conservación de solicitudes antiguas del Yonke', () {
    test('ApiYonkeRequestsRepository conserva solicitudes antiguas aunque la API devuelva menos', () async {
      // 1. Primera llamada con 2 solicitudes
      final client1 = _DummyApiClient({
        'data': [
          {
            'guidId': 'asignacion-1',
            'solicitudGuidId': 'solicitud-1',
            'piezaBuscada': 'Alternador',
            'estatusId': 1,
            'fechaEnvio': '2026-01-01T10:00:00Z',
          },
          {
            'guidId': 'asignacion-2',
            'solicitudGuidId': 'solicitud-2',
            'piezaBuscada': 'Radiador',
            'estatusId': 1,
            'fechaEnvio': '2026-01-02T10:00:00Z',
          },
        ],
      });
      final repo1 = ApiYonkeRequestsRepository(RequestsApi(client1));
      final res1 = await repo1.getAssignedRequests(page: 1, pageSize: 20);
      expect(res1.items.length, 2);

      // 2. Segunda llamada donde la API solo entrega 1 nueva y ya no incluye la antigua
      final client2 = _DummyApiClient({
        'data': [
          {
            'guidId': 'asignacion-3',
            'solicitudGuidId': 'solicitud-3',
            'piezaBuscada': 'Compresor A/C',
            'estatusId': 1,
            'fechaEnvio': '2026-02-01T10:00:00Z',
          },
        ],
      });
      final repo2 = ApiYonkeRequestsRepository(RequestsApi(client2));
      final res2 = await repo2.getAssignedRequests(page: 1, pageSize: 20);

      // Debe conservar las 2 antiguas MÁS la nueva (total 3)
      expect(res2.items.length, 3);
      expect(res2.items.any((r) => r.requestYonkeId == 'asignacion-1'), isTrue);
      expect(res2.items.any((r) => r.requestYonkeId == 'asignacion-2'), isTrue);
      expect(res2.items.any((r) => r.requestYonkeId == 'asignacion-3'), isTrue);
    });

    test('ApiYonkeRequestsRepository aisla las solicitudes asignadas por correo del yonke', () async {
      const storage = FlutterSecureStorage();

      // Yonke A
      await storage.write(key: 'yonke.active_email', value: 'yonke_a@refanet.com');
      final clientA = _DummyApiClient({
        'data': [
          {
            'guidId': 'asig-a-1',
            'solicitudGuidId': 'sol-a-1',
            'piezaBuscada': 'Motor v8',
            'estatusId': 1,
            'fechaEnvio': '2026-03-01T10:00:00Z',
          },
        ],
      });
      final repoA = ApiYonkeRequestsRepository(RequestsApi(clientA), storage);
      final resA = await repoA.getAssignedRequests(page: 1, pageSize: 20);
      expect(resA.items.length, 1);
      expect(resA.items.first.requestYonkeId, 'asig-a-1');

      // Yonke B entra en la misma app
      await storage.write(key: 'yonke.active_email', value: 'yonke_b@refanet.com');
      final clientB = _DummyApiClient({
        'data': [
          {
            'guidId': 'asig-b-1',
            'solicitudGuidId': 'sol-b-1',
            'piezaBuscada': 'Faro Izquierdo',
            'estatusId': 1,
            'fechaEnvio': '2026-03-02T10:00:00Z',
          },
        ],
      });
      final repoB = ApiYonkeRequestsRepository(RequestsApi(clientB), storage);
      final resB = await repoB.getAssignedRequests(page: 1, pageSize: 20);
      expect(resB.items.length, 1);
      expect(resB.items.first.requestYonkeId, 'asig-b-1');

      // Yonke A vuelve a ingresar: debe ver solo lo de A
      await storage.write(key: 'yonke.active_email', value: 'yonke_a@refanet.com');
      final emptyApi = _DummyApiClient({'data': []});
      final repoAReturn = ApiYonkeRequestsRepository(RequestsApi(emptyApi), storage);
      final resAReturn = await repoAReturn.getAssignedRequests(page: 1, pageSize: 20);
      expect(resAReturn.items.length, 1);
      expect(resAReturn.items.first.requestYonkeId, 'asig-a-1');
    });
  });

  group('Aislamiento por correo para Solicitudes del Cliente', () {
    test('ClientRequestsMemory aisla solicitudes por cada correo', () async {
      final memory = ClientRequestsMemory();

      await memory.addSingleRequest(
        'cliente1@gmail.com',
        const ClientRequestSummary(
          id: 'req-cliente-1',
          part: 'Transmisión',
          status: 'En proceso',
          quoteCount: 0,
        ),
      );

      await memory.addSingleRequest(
        'cliente2@gmail.com',
        const ClientRequestSummary(
          id: 'req-cliente-2',
          part: 'Bomba de agua',
          status: 'En proceso',
          quoteCount: 1,
        ),
      );

      final reqs1 = await memory.loadRequests('cliente1@gmail.com');
      final reqs2 = await memory.loadRequests('cliente2@gmail.com');

      expect(reqs1.length, 1);
      expect(reqs1.first.id, 'req-cliente-1');

      expect(reqs2.length, 1);
      expect(reqs2.first.id, 'req-cliente-2');

      // Si se intenta guardar lista vacía de la API, no borra el histórico
      await memory.saveRequests('cliente1@gmail.com', const []);
      final reqs1StillPresent = await memory.loadRequests('cliente1@gmail.com');
      expect(reqs1StillPresent.length, 1);
    });
  });

  group('Historial y persistencia de Cotizaciones del Yonke', () {
    test('ApiYonkeQuotesRepository conserva cotizaciones y las aisla por correo', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'yonke.active_email', value: 'yonke1@refanet.com');

      final dummyQuotesApi = _DummyApiClient({
        'data': [
          {
            'guidId': 'quote-1',
            'solicitudYonkeGuidId': 'asig-1',
            'solicitudGuidId': 'sol-1',
            'precio': 1500.0,
            'disponible': true,
            'esNueva': false,
            'tieneGarantia': true,
            'diasGarantia': 30,
            'envioDisponible': true,
            'activo': true,
            'estatusId': 2, // Aceptada
            'solicitudYonkes': {
              'guidId': 'asig-1',
              'solicitudGuidId': 'sol-1',
              'solicitudes': {
                'piezaBuscada': 'Caja de velocidades',
              },
            },
          },
        ],
      });

      final repo = ApiYonkeQuotesRepository(
        DashboardApi(_DummyApiClient()),
        QuotesApi(dummyQuotesApi),
        null,
        storage,
      );

      final page1 = await repo.getMyQuotes(page: 1, pageSize: 20);
      expect(page1.items.length, 1);
      expect(page1.items.first.id, 'quote-1');
      expect(page1.items.first.status, YonkeQuoteStatus.accepted);

      // Si la API falla o devuelve vacío, el histórico guardado para el yonke sigue disponible
      final failingQuotesApi = _DummyApiClient({'data': []});
      final repoFallback = ApiYonkeQuotesRepository(
        DashboardApi(_DummyApiClient()),
        QuotesApi(failingQuotesApi),
        null,
        storage,
      );

      final pageFallback = await repoFallback.getMyQuotes(page: 1, pageSize: 20);
      expect(pageFallback.items.length, 1);
      expect(pageFallback.items.first.id, 'quote-1');
      expect(pageFallback.items.first.status, YonkeQuoteStatus.accepted);
    });
  });
}
