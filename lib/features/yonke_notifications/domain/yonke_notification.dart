enum YonkeNotificationSetup { demoReady, identityPending, firebasePending }

class YonkeNotificationItem {
  const YonkeNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;
}

class YonkeNotificationSnapshot {
  const YonkeNotificationSnapshot({
    required this.setup,
    required this.notificationsEnabled,
    required this.items,
  });

  final YonkeNotificationSetup setup;
  final bool notificationsEnabled;
  final List<YonkeNotificationItem> items;
}

class YonkeNotificationIdentityPendingException implements Exception {
  const YonkeNotificationIdentityPendingException();
}
