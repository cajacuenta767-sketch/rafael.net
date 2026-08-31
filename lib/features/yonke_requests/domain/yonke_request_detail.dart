import 'dart:typed_data';

import 'yonke_request_summary.dart';

class YonkeRequestDetail {
  const YonkeRequestDetail({
    required this.requestId,
    required this.requestYonkeId,
    required this.part,
    required this.status,
    required this.imageUrls,
    required this.isDemo,
    this.brandId,
    this.brand,
    this.model,
    this.year,
    this.engine,
    this.transmission,
    this.partNumber,
    this.description,
    this.folio,
    this.city,
    this.receivedAt,
    this.closed = false,
  });

  final String requestId;
  final String requestYonkeId;
  final String part;
  final YonkeRequestStatus status;
  final List<String> imageUrls;
  final bool isDemo;
  final int? brandId;
  final String? brand;
  final String? model;
  final int? year;
  final String? engine;
  final String? transmission;
  final String? partNumber;
  final String? description;
  final String? folio;
  final String? city;
  final DateTime? receivedAt;
  final bool closed;

  String get vehicle => [
    brand,
    model,
    year?.toString(),
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

  bool get canRespond =>
      !closed &&
      status != YonkeRequestStatus.quoted &&
      status != YonkeRequestStatus.unavailable;

  YonkeRequestDetail copyWith({YonkeRequestStatus? status}) =>
      YonkeRequestDetail(
        requestId: requestId,
        requestYonkeId: requestYonkeId,
        part: part,
        status: status ?? this.status,
        imageUrls: imageUrls,
        isDemo: isDemo,
        brandId: brandId,
        brand: brand,
        model: model,
        year: year,
        engine: engine,
        transmission: transmission,
        partNumber: partNumber,
        description: description,
        folio: folio,
        city: city,
        receivedAt: receivedAt,
        closed: closed,
      );
}

class YonkeQuoteSubmission {
  const YonkeQuoteSubmission({
    required this.price,
    required this.isNew,
    required this.hasWarranty,
    required this.warrantyDays,
    required this.shippingAvailable,
    this.brandId,
    this.partNumber,
    this.comments,
    this.deliveryDays,
    this.shippingCost,
    this.images = const [],
  });

  final double price;
  final bool isNew;
  final int? brandId;
  final String? partNumber;
  final String? comments;
  final int? deliveryDays;
  final bool hasWarranty;
  final int warrantyDays;
  final bool shippingAvailable;
  final double? shippingCost;
  final List<YonkeQuoteImage> images;
}

class YonkeQuoteImage {
  const YonkeQuoteImage({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
