import 'package:app_yonke/core/network/api_client.dart';
import 'package:app_yonke/core/storage/token_store.dart';
import 'package:app_yonke/features/dashboard/data/dashboard_api.dart';
import 'package:app_yonke/features/messages/data/client_messages_repository.dart';
import 'package:app_yonke/features/profile/data/client_profile_repository.dart';
import 'package:app_yonke/features/profile/domain/client_profile.dart';
import 'package:app_yonke/features/quotes/data/quotes_api.dart';
import 'package:app_yonke/features/quotes/domain/client_contact.dart';
import 'package:app_yonke/features/yonke_messages/data/yonke_messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('línea de contacto', () {
    test('se agrega y se separa sin tocar el texto', () {
      final contact = clientContactFromProfile(
        name: 'Carlos | Mendoza',
        phone: '55 1234 5678',
        photoUrl: 'https://lh3.googleusercontent.com/a/foto',
      )!;
      final signed = signWithClientContact('Hola', contact);

      expect(
        signed,
        'Hola\n\nContacto: Carlos Mendoza | +525512345678 | '
        'https://lh3.googleusercontent.com/a/foto',
      );
      final split = splitClientContact(signed);
      expect(split.text, 'Hola');
      expect(split.contact!.name, 'Carlos Mendoza');
      expect(split.contact!.phone, '+525512345678');
      expect(
        split.contact!.photoUrl,
        'https://lh3.googleusercontent.com/a/foto',
      );
    });

    test('un mensaje normal que empieza con "Contacto:" no se toca', () {
      const text = 'Te aviso\nContacto: mañana temprano';
      final split = splitClientContact(text);

      expect(split.text, text);
      expect(split.contact, isNull);
    });

    test('sin teléfono no se comparte nada', () {
      expect(clientContactFromProfile(name: 'Carlos'), isNull);
    });
  });

  test('el cliente comparte su contacto una vez y el yonke lo ve', () async {
    final api = _ChatApi();
    final client = ApiClientMessagesRepository(
      QuotesApi(api..senderType = 1),
      DashboardApi(api),
      _NoTokens(),
      null,
      _Profile(
        const ClientProfile(name: 'Carlos Mendoza', phone: '+525512345678'),
      ),
    );

    await client.sendMessage(quoteId: 'q-contacto', message: 'Hola');
    await client.sendMessage(quoteId: 'q-contacto', message: '¿Sigue?');

    expect(api.sent, [
      'Hola\n\nContacto: Carlos Mendoza | +525512345678',
      '¿Sigue?',
    ]);

    final yonke = ApiYonkeMessagesRepository(
      QuotesApi(api),
      DashboardApi(api),
      _NoTokens(),
    );
    final messages = await yonke.getConversation('q-contacto');

    expect(messages.map((m) => m.text), ['Hola', '¿Sigue?']);
    expect(messages.first.contact!.name, 'Carlos Mendoza');
    expect(messages.first.contact!.phone, '+525512345678');

    // La app del cliente tampoco muestra la línea en su propio chat.
    final own = await client.getConversation('q-contacto');
    expect(own.first.text, 'Hola');
  });
}

/// Chat en memoria de `SolicitudCotizacionMensajes`.
class _ChatApi implements ApiClient {
  int senderType = 1;
  final sent = <String>[];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => {
    'success': true,
    'data': [
      for (var i = 0; i < sent.length; i++)
        {
          'guidId': 'm-$i',
          'mensaje': sent[i],
          'tipoRemitenteId': 1,
          'fechaCreacion': '2026-09-25T12:0$i:00Z',
        },
    ],
  };

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    sent.add((data as Map)['mensaje'] as String);
    return {'success': true};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async => {'success': true};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements ClientProfileRepository {
  _Profile(this.profile);

  final ClientProfile profile;

  @override
  Future<ClientProfileSnapshot> load() async => ClientProfileSnapshot(
    availability: ClientProfileAvailability.available,
    profile: profile,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoTokens implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Null>.value();
}
