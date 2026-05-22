// Unit tests for CalendarSyncError sealed subclasses.
//
// Verifies that each sealed variant constructs correctly and that the
// sealed class hierarchy behaves as expected (exhaustive switch coverage,
// type identity, ApiFailureError message field).

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';

void main() {
  group('CalendarSyncError sealed subclasses', () {
    test('EmailMismatchError is a CalendarSyncError', () {
      final error = EmailMismatchError();
      expect(error, isA<CalendarSyncError>());
    });

    test('CancelledError is a CalendarSyncError', () {
      final error = CancelledError();
      expect(error, isA<CalendarSyncError>());
    });

    test('ApiFailureError is a CalendarSyncError', () {
      final error = ApiFailureError('patch failed: 403');
      expect(error, isA<CalendarSyncError>());
    });

    test('ApiFailureError stores message field', () {
      const msg = 'events.patch failed errorCode=403';
      final error = ApiFailureError(msg);
      expect(error.message, msg);
    });

    test('ApiFailureError message must not be empty (consumer check)', () {
      final error = ApiFailureError('non-empty');
      expect(error.message.isNotEmpty, isTrue);
    });

    test('EmailMismatchError and CancelledError are distinct types', () {
      final emailErr = EmailMismatchError();
      final cancelledErr = CancelledError();
      expect(emailErr, isNot(isA<CancelledError>()));
      expect(cancelledErr, isNot(isA<EmailMismatchError>()));
    });

    test('exhaustive switch over CalendarSyncError covers all variants', () {
      // This test will fail to compile if a new variant is added but the
      // switch is not updated, ensuring the sealed class is properly exhausted.
      final errors = <CalendarSyncError>[
        EmailMismatchError(),
        CancelledError(),
        ApiFailureError('api error'),
      ];

      final labels = errors.map((e) {
        return switch (e) {
          EmailMismatchError() => 'mismatch',
          CancelledError() => 'cancelled',
          ApiFailureError() => 'api_failure',
        };
      }).toList();

      expect(labels, ['mismatch', 'cancelled', 'api_failure']);
    });

    test('two ApiFailureError instances with same message are not identical', () {
      final a = ApiFailureError('error');
      final b = ApiFailureError('error');
      // They are different object instances but carry the same message value.
      expect(a.message, b.message);
      expect(identical(a, b), isFalse);
    });
  });
}
