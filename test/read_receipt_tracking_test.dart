import 'package:app_yonke/core/realtime/read_receipt_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tracker with ReadReceiptTracking {}

void main() {
  test(
    'fallo no bloquea historial, persiste aviso y éxito lo limpia',
    () async {
      final tracker = _Tracker();
      await tracker.synchronizeReadReceipt('quote-a', () async {
        throw StateError('offline');
      });
      expect(tracker.readReceiptPending('quote-a'), isTrue);
      expect(tracker.readReceiptPending('quote-b'), isFalse);
      await tracker.synchronizeReadReceipt('quote-a', () async {});
      expect(tracker.readReceiptPending('quote-a'), isFalse);
    },
  );
}
