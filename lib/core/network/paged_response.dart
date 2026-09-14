/// Lectura de respuestas paginadas del servidor.
///
/// Forma confirmada contra el servidor real (13 de septiembre de 2026):
///
/// ```json
/// { "success": true, "message": "Busqueda exitosa.",
///   "data": { "data": [ ... ], "meta": { "page": 1, "take": 10,
///                                        "itemCount": 0, "pageCount": 0 } },
///   "statusCode": 200, "errors": null }
/// ```
///
/// También acepta las variantes que la app manejaba antes (`items`,
/// `registros`, lista directa en `data`).
library;

class PageMeta {
  const PageMeta({
    required this.page,
    required this.take,
    required this.itemCount,
    required this.pageCount,
  });

  final int page;
  final int take;
  final int itemCount;
  final int pageCount;

  bool get hasMore => page < pageCount;
}

/// Registros de una respuesta paginada o de lista. Lista vacía si no hay.
List<dynamic> pagedRecords(dynamic response) {
  if (response is List) return response;
  if (response is! Map) return const [];
  final data = response.containsKey('data') ? response['data'] : response;
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['data', 'items', 'registros']) {
      final value = data[key];
      if (value is List) return value;
    }
  }
  for (final key in const ['items', 'registros']) {
    final value = response[key];
    if (value is List) return value;
  }
  return const [];
}

/// `meta` de la respuesta paginada, si el servidor la incluye.
PageMeta? pageMetaFromResponse(dynamic response) {
  if (response is! Map) return null;
  final data = response['data'];
  final meta = data is Map ? data['meta'] : response['meta'];
  if (meta is! Map) return null;
  int read(String key, int fallback) {
    final value = meta[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  return PageMeta(
    page: read('page', 1),
    take: read('take', 0),
    itemCount: read('itemCount', 0),
    pageCount: read('pageCount', 0),
  );
}
