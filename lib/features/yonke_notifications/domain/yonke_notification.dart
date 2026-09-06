enum YonkeNotificationSetup { identityPending, firebasePending }

class YonkeNotificationSnapshot {
  const YonkeNotificationSnapshot({required this.setup});

  final YonkeNotificationSetup setup;
}

class YonkeNotificationIdentityPendingException implements Exception {
  const YonkeNotificationIdentityPendingException();
}
