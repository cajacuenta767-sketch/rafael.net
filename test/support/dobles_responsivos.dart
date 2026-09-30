// Dobles de prueba mínimos para montar las páginas de la matriz responsive.
// Son copias públicas de los fakes privados que ya usan otros tests
// (widget_test.dart, client_profile_test.dart, client_yonkes_test.dart,
// linked_client_home_screenshot_test.dart, yonke_*_screenshot_test.dart).

import 'dart:typed_data';

import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/network/api_file.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/auth/domain/client_auth_repository.dart';
import 'package:app_yonke/features/auth/domain/yonke_auth_repository.dart';
import 'package:app_yonke/features/catalogs/data/catalogs_api.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/yonke_messages/data/yonke_messages_repository.dart';
import 'package:app_yonke/features/yonke_messages/domain/quote_client.dart';
import 'package:app_yonke/features/yonke_messages/domain/yonke_message.dart';
import 'package:app_yonke/features/yonke_profile/data/yonke_profile_repository.dart';
import 'package:app_yonke/features/yonke_profile/domain/yonke_profile.dart';
import 'package:app_yonke/features/yonke_quotes/data/yonke_quotes_repository.dart';
import 'package:app_yonke/features/yonke_quotes/domain/yonke_quote.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_request_detail_repository.dart';
import 'package:app_yonke/features/yonke_requests/data/yonke_requests_repository.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_detail.dart';
import 'package:app_yonke/features/yonke_requests/domain/yonke_request_summary.dart';
import 'package:app_yonke/features/yonkes/data/client_yonkes_repository.dart';
import 'package:app_yonke/features/yonkes/data/yonkes_api.dart';
import 'package:app_yonke/features/yonkes/domain/client_yonke.dart';

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

class TokenStoreMemoriaDoble implements TokenStore {
  TokenStoreMemoriaDoble({this.accessToken, this.yonkeGuidId});

  String? accessToken;
  String? refreshToken;
  DateTime? expiresAt;
  String? yonkeGuidId;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    yonkeGuidId = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<String?> readYonkeGuidId() async => yonkeGuidId;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? yonkeGuidId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = expiresAt;
    this.yonkeGuidId = yonkeGuidId;
  }
}

// ---------------------------------------------------------------------------
// Autenticación
// ---------------------------------------------------------------------------

class AuthClientePendienteDoble implements ClientAuthRepository {
  final List<String> requestedPhones = [];

  @override
  Future<ClientOtpVerification> loginWithGoogle(String idToken) async =>
      const ClientOtpVerification(sessionContractPending: true);

  @override
  Future<void> requestOtp(String phone) async => requestedPhones.add(phone);

  @override
  Future<ClientOtpVerification> verifyOtp({
    required String phone,
    required String code,
  }) async => const ClientOtpVerification(sessionContractPending: true);
}

class AuthYonkePendienteDoble implements YonkeAuthRepository {
  @override
  Future<YonkeLoginResult> login({
    required String email,
    required String password,
  }) async => const YonkeLoginResult(sessionContractPending: true);
}

// ---------------------------------------------------------------------------
// Cliente: tablero (RoleHomePage.client)
// ---------------------------------------------------------------------------

/// `mis-solicitudes` del cliente con la forma de `Solicitud_Busqueda_DTO`.
class ApiTableroClienteDoble implements ApiClient {
  static Map<String, Object> _solicitud(String id, String part, int day) => {
    'guidId': id,
    'piezaBuscada': part,
    'marca': 'Nissan',
    'modelo': 'Sentra',
    'año': 2015,
    'estatusSolicitud': 'Enviada',
    'folio': 'SOL-2026090$day',
    'fechaCreacion': '2026-09-0${day}T10:00:00Z',
    'totalCotizaciones': 1,
  };

  static final _solicitudes = {
    'success': true,
    'data': {
      'data': [
        _solicitud('s1', 'Alternador', 3),
        _solicitud('s2', 'Compresor A/C', 2),
        _solicitud('s3', 'Transmisión automática', 1),
      ],
    },
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => switch (path) {
    '/api/DashboardSuscriptores/mis-solicitudes' => _solicitudes,
    _ => {'success': true, 'data': <Object>[]},
  };

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  Future<dynamic> multipart(
    String path, {
    required String method,
    Map<String, dynamic>? fields,
    List<ApiFile> files = const [],
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};
}

// ---------------------------------------------------------------------------
// Cliente: perfil
// ---------------------------------------------------------------------------

class PerfilClienteDoble implements ClientProfileRepository {
  ClientProfile profile = const ClientProfile(
    name: 'Noe Gamez',
    email: 'nogamez@email.com',
  );
  List<ClientAddress> addresses = [];
  bool notificationsEnabled = true;

  @override
  Future<ClientProfileSnapshot> load() async => ClientProfileSnapshot(
    availability: ClientProfileAvailability.available,
    profile: profile,
  );

  @override
  Future<List<ClientAddress>> loadAddresses() async => addresses;

  @override
  Future<bool> readNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<void> saveAddresses(List<ClientAddress> value) async {
    addresses = value;
  }

  @override
  Future<void> saveProfile(ClientProfile value) async {
    profile = value;
  }

  @override
  Future<void> writeNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
  }

  @override
  Future<bool> needsOnboarding() async => false;

  @override
  Future<ClientProfile> draftForOnboarding() async => const ClientProfile();

  @override
  Future<void> saveLoginHints(ClientLoginHints hints) async {}

  @override
  Future<String> savePhoto(
    Uint8List bytes, {
    required String extension,
  }) async => '/tmp/foto.$extension';

  @override
  Future<void> deletePhoto(String path) async {}
}

// ---------------------------------------------------------------------------
// Cliente: yonkes
// ---------------------------------------------------------------------------

const yonkesDemo = [
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

class YonkesClienteDoble implements ClientYonkesRepository {
  const YonkesClienteDoble();

  @override
  Future<ClientYonkePage> getPage({
    required int page,
    required int pageSize,
    String? search,
    int? cityId,
  }) async {
    final query = search?.toLowerCase();
    return ClientYonkePage(
      items: yonkesDemo
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

// ---------------------------------------------------------------------------
// Yonke: solicitudes y cotizaciones
// ---------------------------------------------------------------------------

/// Solicitudes de muestra con la forma que produce el parser de la bandeja.
final solicitudesYonkeDemo = <YonkeRequestSummary>[
  YonkeRequestSummary(
    requestId: 'request-alternador',
    requestYonkeId: 'assignment-alternador',
    part: 'Alternador',
    status: YonkeRequestStatus.newRequest,
    receivedAt: DateTime(2026, 8, 31, 9, 20),
    brand: 'Nissan',
    model: 'Sentra',
    year: 2018,
    city: 'Nogales, Sonora',
    folio: 'RF-001',
    photoCount: 4,
  ),
  YonkeRequestSummary(
    requestId: 'request-faro',
    requestYonkeId: 'assignment-faro',
    part: 'Faro delantero',
    status: YonkeRequestStatus.viewed,
    receivedAt: DateTime(2026, 8, 30, 17, 45),
    brand: 'Toyota',
    model: 'Corolla',
    year: 2016,
    city: 'Hermosillo, Sonora',
    folio: 'RF-002',
    photoCount: 2,
  ),
  YonkeRequestSummary(
    requestId: 'request-transmision',
    requestYonkeId: 'assignment-transmision',
    part: 'Transmisión automática',
    status: YonkeRequestStatus.quoted,
    receivedAt: DateTime(2026, 8, 29, 14, 10),
    brand: 'Ford',
    model: 'Ranger',
    year: 2020,
    city: 'Agua Prieta, Sonora',
    folio: 'RF-003',
    photoCount: 3,
    hasQuote: true,
  ),
];

class SolicitudesYonkeDemoDoble implements YonkeRequestsRepository {
  const SolicitudesYonkeDemoDoble();

  @override
  Future<YonkeRequestsPageResult> getAssignedRequests({
    required int page,
    required int pageSize,
    String? search,
    YonkeRequestFilters filters = const YonkeRequestFilters(),
  }) async {
    final query = normalizarTexto(search ?? '');
    final items = solicitudesYonkeDemo.where((item) {
      final searchable = normalizarTexto(
        [
          item.part,
          item.brand,
          item.model,
          item.year,
          item.folio,
          item.city,
        ].whereType<Object>().join(' '),
      );
      return (query.isEmpty || searchable.contains(query)) &&
          (filters.status == null || item.status == filters.status) &&
          (filters.city == null || item.city == filters.city);
    }).toList();
    return YonkeRequestsPageResult(items: items, page: 1, hasMore: false);
  }

  @override
  Future<void> markAsViewed(String requestYonkeId) async {}
}

class DetalleSolicitudYonkeDemoDoble implements YonkeRequestDetailRepository {
  const DetalleSolicitudYonkeDemoDoble();

  @override
  Future<YonkeRequestDetail> getDetail({
    required String requestId,
    required String requestYonkeId,
    YonkeRequestSummary? summary,
  }) async {
    final source =
        summary ??
        solicitudesYonkeDemo.firstWhere((item) => item.requestId == requestId);
    return YonkeRequestDetail(
      requestId: source.requestId,
      requestYonkeId: source.requestYonkeId,
      part: source.part,
      status: source.status,
      imageUrls: const [],
      brandId: 1,
      brand: source.brand,
      model: source.model,
      year: source.year,
      engine: '2.0 L',
      transmission: 'Automática',
      partNumber: '23100-3SH1A',
      description: 'Original o compatible, funcionando y en buen estado.',
      folio: source.folio,
      city: source.city,
      receivedAt: source.receivedAt,
    );
  }

  @override
  Future<void> markUnavailable(String requestYonkeId, {int? brandId}) async {}

  @override
  Future<void> submitQuote(
    String requestYonkeId,
    YonkeQuoteSubmission submission, {
    YonkeRequestDetail? detail,
  }) async {}
}

/// Cotizaciones de muestra con la forma que produce `yonkeQuoteFromJson`.
final cotizacionesYonkeDemo = <YonkeQuote>[
  YonkeQuote(
    id: 'quote-alternador',
    requestYonkeId: 'assignment-alternador',
    requestId: 'request-alternador',
    part: 'Alternador',
    price: 1850,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 30,
    shippingAvailable: true,
    shippingCost: 120,
    active: true,
    status: YonkeQuoteStatus.viewed,
    createdAt: DateTime(2026, 8, 31, 11, 25),
    imageUrls: const [],
    brand: 'Nissan',
    model: 'Sentra',
    year: 2018,
    folio: 'RF-001',
    partNumber: '23100-3SH1A',
    comments: 'Pieza original usada, probada y en buen estado.',
    deliveryDays: 2,
  ),
  YonkeQuote(
    id: 'quote-faro',
    requestYonkeId: 'assignment-faro',
    requestId: 'request-faro',
    part: 'Faro delantero',
    price: 950,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 15,
    shippingAvailable: false,
    active: true,
    status: YonkeQuoteStatus.sent,
    createdAt: DateTime(2026, 8, 30, 18, 10),
    imageUrls: const [],
    brand: 'Toyota',
    model: 'Corolla',
    year: 2016,
    folio: 'RF-002',
    comments: 'Faro usado completo, sin roturas.',
  ),
  YonkeQuote(
    id: 'quote-transmision',
    requestYonkeId: 'assignment-transmision',
    requestId: 'request-transmision',
    part: 'Transmisión automática',
    price: 14500,
    available: true,
    isNew: false,
    hasWarranty: true,
    warrantyDays: 60,
    shippingAvailable: true,
    shippingCost: 850,
    active: true,
    status: YonkeQuoteStatus.accepted,
    createdAt: DateTime(2026, 8, 29, 15, 45),
    imageUrls: const [],
    brand: 'Ford',
    model: 'Ranger',
    year: 2020,
    folio: 'RF-003',
    comments: 'Transmisión probada con garantía.',
    deliveryDays: 3,
  ),
];

class CotizacionesYonkeDemoDoble implements YonkeQuotesRepository {
  const CotizacionesYonkeDemoDoble();

  @override
  Future<YonkeQuotesPageResult> getMyQuotes({
    required int page,
    required int pageSize,
    String? search,
    YonkeQuoteFilters filters = const YonkeQuoteFilters(),
  }) async {
    final query = normalizarTexto(search ?? '');
    final items = cotizacionesYonkeDemo.where((quote) {
      final searchable = normalizarTexto(
        [
          quote.part,
          quote.brand,
          quote.model,
          quote.year,
          quote.folio,
          quote.partNumber,
        ].whereType<Object>().join(' '),
      );
      return (query.isEmpty || searchable.contains(query)) &&
          (filters.status == null || quote.status == filters.status) &&
          (filters.onlyAvailable == null ||
              quote.available == filters.onlyAvailable);
    }).toList();
    return YonkeQuotesPageResult(items: items, page: 1, hasMore: false);
  }

  @override
  Future<YonkeQuote> getById(String quoteId) async =>
      cotizacionesYonkeDemo.firstWhere(
        (quote) => quote.id == quoteId,
        orElse: () => throw const YonkeQuoteNotFoundException(),
      );
}

// ---------------------------------------------------------------------------
// Yonke: mensajes y perfil
// ---------------------------------------------------------------------------

class MensajesYonkeDoble implements YonkeMessagesRepository {
  const MensajesYonkeDoble();

  @override
  Future<List<YonkeMessagePreview>> getInbox() async {
    final now = DateTime(2026, 9, 8, 12);
    return [
      YonkeMessagePreview(
        quote: YonkeQuote(
          id: 'q-1',
          requestId: 'r-1',
          requestYonkeId: 'ry-1',
          part: 'Faro delantero izquierdo',
          brand: 'Toyota',
          model: 'Corolla',
          year: 2020,
          price: 1850,
          folio: 'COT-015',
          status: YonkeQuoteStatus.accepted,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 30,
          shippingAvailable: true,
          createdAt: now.subtract(const Duration(hours: 2)),
          imageUrls: const [],
        ),
        clientLabel: 'Carlos Mendoza',
        lastMessage: '¿Aceptas transferencia bancaria?',
        lastMessageAt: now.subtract(const Duration(minutes: 18)),
        unreadCount: 2,
      ),
      YonkeMessagePreview(
        quote: YonkeQuote(
          id: 'q-2',
          requestId: 'r-2',
          requestYonkeId: 'ry-2',
          part: 'Alternador',
          brand: 'Chevrolet',
          model: 'Silverado',
          year: 2018,
          price: 2400,
          folio: 'COT-014',
          status: YonkeQuoteStatus.sent,
          available: true,
          active: true,
          isNew: false,
          hasWarranty: true,
          warrantyDays: 60,
          shippingAvailable: true,
          createdAt: now.subtract(const Duration(hours: 5)),
          imageUrls: const [],
        ),
        clientLabel: 'Taller Mecánico El Rayo',
        lastMessage: 'Perfecto, hoy paso por él a las 3 pm.',
        lastMessageAt: now.subtract(const Duration(hours: 1)),
        unreadCount: 0,
      ),
    ];
  }

  @override
  Future<List<YonkeQuoteMessage>> getConversation(String quoteId) async => [];

  @override
  Future<QuoteClient?> getClient(String quoteId) async => null;

  @override
  Future<void> sendMessage({
    required String quoteId,
    required String message,
  }) async {}
}

class PerfilYonkeDoble implements YonkeProfileRepository {
  const PerfilYonkeDoble();

  @override
  Future<YonkeProfileSnapshot> load() async => const YonkeProfileSnapshot(
    availability: YonkeProfileAvailability.available,
    profile: YonkeProfile(
      guidId: 'yonke-guid-1',
      name: 'Yonke El Profe',
      phone: '+52 631 123 4567',
      address: 'Periférico Luis Donaldo Colosio #1420',
      email: 'contacto@yonkelprofe.com',
      city: 'Nogales, Sonora',
      postalCode: 84000,
    ),
  );
}

// ---------------------------------------------------------------------------
// Yonke: registro (catálogos)
// ---------------------------------------------------------------------------

class CatalogosApiDoble implements CatalogsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dynamic> getStates() async => {
    'data': [
      {'id': 26, 'entidad': 'Sonora'},
      {'id': 2, 'entidad': 'Baja California'},
    ],
  };

  @override
  Future<dynamic> getCitiesByState(int stateId) async => {
    'data': [
      {'id': 1, 'ciudad': 'Nogales'},
      {'id': 2, 'ciudad': 'Hermosillo'},
      {'id': 3, 'ciudad': 'Ciudad Obregón'},
    ],
  };
}

class YonkesApiDoble implements YonkesApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<dynamic> register({
    required Map<String, dynamic> fields,
    List<ApiFile> files = const [],
  }) async => {'success': true};
}

// ---------------------------------------------------------------------------

String normalizarTexto(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[áàä]'), 'a')
    .replaceAll(RegExp(r'[éèë]'), 'e')
    .replaceAll(RegExp(r'[íìï]'), 'i')
    .replaceAll(RegExp(r'[óòö]'), 'o')
    .replaceAll(RegExp(r'[úùü]'), 'u');
