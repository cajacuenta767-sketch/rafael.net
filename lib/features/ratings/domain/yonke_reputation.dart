class YonkeRatingRecord {
  const YonkeRatingRecord({required this.rating, this.comment, this.createdAt});

  final int rating;
  final String? comment;
  final DateTime? createdAt;
}

class YonkeReputation {
  const YonkeReputation({this.records = const [], double? average, int? count})
    : explicitAverage = average,
      explicitCount = count;

  final List<YonkeRatingRecord> records;
  final double? explicitAverage;
  final int? explicitCount;

  int get count => explicitCount ?? records.length;

  double get average =>
      explicitAverage ??
      (count == 0
          ? 0
          : records.fold<int>(0, (total, item) => total + item.rating) / count);

  List<YonkeRatingRecord> get comments => records
      .where((item) => item.comment != null && item.comment!.isNotEmpty)
      .take(2)
      .toList(growable: false);
}
