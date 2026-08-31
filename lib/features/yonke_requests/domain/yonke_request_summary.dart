enum YonkeRequestStatus {
  newRequest,
  viewed,
  quoted,
  unavailable,
  closed,
  unknown,
}

extension YonkeRequestStatusLabel on YonkeRequestStatus {
  String get label => switch (this) {
    YonkeRequestStatus.newRequest => 'Nueva',
    YonkeRequestStatus.viewed => 'Vista',
    YonkeRequestStatus.quoted => 'Cotizada',
    YonkeRequestStatus.unavailable => 'No disponible',
    YonkeRequestStatus.closed => 'Cerrada',
    YonkeRequestStatus.unknown => 'Sin estado',
  };
}

class YonkeRequestSummary {
  const YonkeRequestSummary({
    required this.requestId,
    required this.requestYonkeId,
    required this.part,
    required this.status,
    required this.receivedAt,
    required this.isDemo,
    this.brand,
    this.model,
    this.year,
    this.city,
    this.folio,
    this.photoCount = 0,
    this.hasQuote = false,
  });

  final String requestId;
  final String requestYonkeId;
  final String part;
  final YonkeRequestStatus status;
  final DateTime receivedAt;
  final bool isDemo;
  final String? brand;
  final String? model;
  final int? year;
  final String? city;
  final String? folio;
  final int photoCount;
  final bool hasQuote;

  bool get isNew => status == YonkeRequestStatus.newRequest;

  String get vehicle => [
    brand,
    model,
    year?.toString(),
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

  YonkeRequestSummary copyWith({YonkeRequestStatus? status}) =>
      YonkeRequestSummary(
        requestId: requestId,
        requestYonkeId: requestYonkeId,
        part: part,
        status: status ?? this.status,
        receivedAt: receivedAt,
        isDemo: isDemo,
        brand: brand,
        model: model,
        year: year,
        city: city,
        folio: folio,
        photoCount: photoCount,
        hasQuote: hasQuote,
      );
}

class YonkeRequestFilters {
  const YonkeRequestFilters({this.status, this.city, this.from, this.to});

  final YonkeRequestStatus? status;
  final String? city;
  final DateTime? from;
  final DateTime? to;

  int get activeCount =>
      [status, city, from, to].where((value) => value != null).length;

  bool get isEmpty => activeCount == 0;

  YonkeRequestFilters copyWith({
    YonkeRequestStatus? status,
    String? city,
    DateTime? from,
    DateTime? to,
    bool clearStatus = false,
    bool clearCity = false,
    bool clearDates = false,
  }) => YonkeRequestFilters(
    status: clearStatus ? null : status ?? this.status,
    city: clearCity ? null : city ?? this.city,
    from: clearDates ? null : from ?? this.from,
    to: clearDates ? null : to ?? this.to,
  );
}

class YonkeRequestsPageResult {
  const YonkeRequestsPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<YonkeRequestSummary> items;
  final int page;
  final bool hasMore;
}
