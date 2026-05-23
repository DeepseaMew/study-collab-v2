import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_result.freezed.dart';

/// Domain entity representing the result of a Google Calendar sync operation.
///
/// Zero Flutter or Firebase imports — pure Dart.
@freezed
abstract class SyncResult with _$SyncResult {
  const factory SyncResult({
    required int syncedCount,
    required int failedCount,
    required DateTime syncedAt,
  }) = _SyncResult;
}
