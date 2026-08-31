import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/part_search.dart';

abstract interface class SearchHistoryRepository {
  Future<List<SearchHistoryEntry>> read();
  Future<void> write(List<SearchHistoryEntry> entries);
}

class SecureSearchHistoryRepository implements SearchHistoryRepository {
  SecureSearchHistoryRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'client.search_history.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<SearchHistoryEntry>> read() async {
    try {
      final value = await _storage.read(key: _key);
      if (value == null || value.isEmpty) return const [];
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => SearchHistoryEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((entry) => entry.query.trim().isNotEmpty)
          .take(8)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<SearchHistoryEntry> entries) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode(
          entries.take(8).map((entry) => entry.toJson()).toList(),
        ),
      );
    } catch (_) {
      // El historial es auxiliar: un fallo local no debe impedir buscar.
    }
  }
}

class MemorySearchHistoryRepository implements SearchHistoryRepository {
  List<SearchHistoryEntry> entries;

  MemorySearchHistoryRepository([this.entries = const []]);

  @override
  Future<List<SearchHistoryEntry>> read() async => List.of(entries);

  @override
  Future<void> write(List<SearchHistoryEntry> value) async {
    entries = List.of(value);
  }
}
