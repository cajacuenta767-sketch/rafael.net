import 'package:app_yonke/core/network/api_endpoints.dart';
import 'package:app_yonke/features/requests/domain/client_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Request Recipients and Client Profile tests', () {
    test('ApiEndpoints defines clientProfile and requestRecipients correctly', () {
      expect(
        ApiEndpoints.clientProfile('11111111-1111-1111-1111-111111111111'),
        '/api/ClienteAuth/11111111-1111-1111-1111-111111111111',
      );
      expect(
        ApiEndpoints.requestRecipients('22222222-2222-2222-2222-222222222222'),
        '/api/SolicitudYonkes/solicitud/22222222-2222-2222-2222-222222222222/destinatarios',
      );
    });

    test('requestRecipientsFromResponse parses recipient records correctly', () {
      final sampleResponse = {
        'data': [
          {
            'solicitudYonkeGuidId': '33333333-3333-3333-3333-333333333333',
            'yonkeGuidId': '44444444-4444-4444-4444-444444444444',
            'nombreYonke': 'Yonke San Juan',
            'logo': 'https://example.com/logo.png',
            'telefono': '6641234567',
            'estatusId': 1,
            'estatus': 'Enviada',
            'fechaEnvio': '2026-10-01T12:00:00Z',
            'vista': false,
            'fechaVista': null,
          },
          {
            'solicitudYonkeGuidId': '55555555-5555-5555-5555-555555555555',
            'yonkeGuidId': '66666666-6666-6666-6666-666666666666',
            'nombreYonke': 'Yonke El Rayo',
            'logo': null,
            'telefono': '6647654321',
            'estatusId': 2,
            'estatus': 'Vista',
            'fechaEnvio': '2026-10-01T12:05:00Z',
            'vista': true,
            'fechaVista': '2026-10-01T12:10:00Z',
          }
        ]
      };

      final recipients = requestRecipientsFromResponse(sampleResponse);
      expect(recipients.length, 2);

      final r1 = recipients[0];
      expect(r1.id, '33333333-3333-3333-3333-333333333333');
      expect(r1.yonkeId, '44444444-4444-4444-4444-444444444444');
      expect(r1.yonkeName, 'Yonke San Juan');
      expect(r1.logoUrl, 'https://example.com/logo.png');
      expect(r1.telephone, '6641234567');
      expect(r1.status, 'Enviada');
      expect(r1.viewed, false);

      final r2 = recipients[1];
      expect(r2.id, '55555555-5555-5555-5555-555555555555');
      expect(r2.yonkeId, '66666666-6666-6666-6666-666666666666');
      expect(r2.yonkeName, 'Yonke El Rayo');
      expect(r2.logoUrl, isNull);
      expect(r2.telephone, '6647654321');
      expect(r2.status, 'Vista');
      expect(r2.viewed, true);
    });
  });
}
