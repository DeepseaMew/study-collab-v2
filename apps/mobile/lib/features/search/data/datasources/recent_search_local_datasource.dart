import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/logger.dart';

/// Local datasource for recent search terms (ADR 0010 Sub-decision 3).
///
/// Stores a JSON array of strings in [flutter_secure_storage] under the key
/// `search_recent_<uid>`. The UID scope prevents cross-user leakage on
/// shared devices. Maximum 10 entries with FIFO eviction.
///
/// No PII may appear in log messages. Search terms are treated as opaque
/// strings and are never logged.
class RecentSearchLocalDatasource {
  RecentSearchLocalDatasource(this._storage);

  RecentSearchLocalDatasource.withDefaults()
    : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const int _maxEntries = 10;
  static String _storageKey(String uid) => 'search_recent_$uid';

  /// Returns the list of recent search terms for [uid], most recent first.
  Future<List<String>> getRecentSearches(String uid) async {
    try {
      final raw = await _storage.read(key: _storageKey(uid));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<String>();
    } catch (e, st) {
      appLogger.error(
        'RecentSearchLocalDatasource.getRecentSearches failed',
        exception: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Adds [term] to the recent search list for [uid].
  ///
  /// Deduplicates: if [term] already exists, it is moved to the front.
  /// Evicts the oldest entry when the list exceeds [_maxEntries].
  Future<void> addRecentSearch(String uid, String term) async {
    try {
      final current = await getRecentSearches(uid);
      final updated = [
        term,
        ...current.where((t) => t != term),
      ].take(_maxEntries).toList();
      await _storage.write(key: _storageKey(uid), value: jsonEncode(updated));
      appLogger.debug(
        'RecentSearchLocalDatasource.addRecentSearch',
        extra: {'entryCount': updated.length},
      );
    } catch (e, st) {
      appLogger.error(
        'RecentSearchLocalDatasource.addRecentSearch failed',
        exception: e,
        stackTrace: st,
      );
    }
  }

  /// Removes all recent search terms for [uid].
  Future<void> clearRecentSearches(String uid) async {
    try {
      await _storage.delete(key: _storageKey(uid));
      appLogger.debug('RecentSearchLocalDatasource.clearRecentSearches');
    } catch (e, st) {
      appLogger.error(
        'RecentSearchLocalDatasource.clearRecentSearches failed',
        exception: e,
        stackTrace: st,
      );
    }
  }
}
