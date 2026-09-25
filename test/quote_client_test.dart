import 'package:app_yonke/features/yonke_messages/domain/quote_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quoteClientFromResponse', () {
    test('la respuesta publicada hoy no trae cliente', () {
      expect(
        quoteClientFromResponse({
          'data': {
            'guidId': 'q1',
            'usuarioId': 'yonke-user',
            'solicitudYonkes': {
              'yonkeGuidId': 'y1',
              'solicitudes': {'usuarioId': 'client-user', 'folio': 'SOL-1'},
            },
          },
        }),
        isNull,
      );
    });

    test('lee el objeto cliente de la solicitud', () {
      final client = quoteClientFromResponse({
        'data': {
          'solicitudYonkes': {
            'solicitudes': {
              'cliente': {
                'nombre': ' Carlos Mendoza ',
                'telefono': '+52 55 1234 5678',
                'fotoPerfil': 'https://cdn.test/c.jpg',
              },
            },
          },
        },
      });

      expect(client!.name, 'Carlos Mendoza');
      expect(client.phone, '+52 55 1234 5678');
      expect(client.photoUrl, 'https://cdn.test/c.jpg');
    });

    test('acepta campos planos y descarta el nombre de relleno', () {
      final client = quoteClientFromResponse({
        'data': {
          'nombreCliente': 'Cliente refaNet',
          'telefonoCliente': '+5215512345678',
          'fotoCliente': 'http://inseguro.test/c.jpg',
        },
      });

      expect(client!.name, isNull);
      expect(client.phone, '+5215512345678');
      expect(client.photoUrl, isNull);
    });
  });
}
