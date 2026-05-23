// Integration test for the Note-Sharing happy path (ADR 0008).
//
// Scaffolded test — skip: true. CI will enable these once:
//   1. Firebase emulator seeds note_sharing_enabled: true in Remote Config.
//   2. Storage rules emulator loads the amended storage.rules (Amendment C).
//   3. Both Android emulator and Web (Chrome) targets are configured.
//
// Happy path:
//   upload file → file appears in list → delete file → file removed from list
//
// These tests run against the Firebase emulator suite (Firestore + Storage +
// Remote Config). They must NOT run against production Firebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Note-Sharing integration — happy path', () {
    // ── Upload happy path ────────────────────────────────────────────────────

    testWidgets(
      'upload PDF under 10 MB → file appears in FilesTab list',
      (tester) async {
        // TODO(CI): Implement once emulators are seeded.
        //
        // Steps:
        //   1. Sign in as a KMUTT-domain user (seeded in auth emulator).
        //   2. Navigate to a session detail screen with the Files tab active.
        //   3. Tap the upload FAB.
        //   4. Inject a mock FilePicker result (≤ 10 MB PDF).
        //   5. pumpAndSettle(Duration(seconds: 5)) — upload completes.
        //   6. Expect: the file name appears in the ListView.
        //   7. Expect: noteCount on the Firestore session document == 1.
      },
      skip: true, // Pending CI emulator configuration (ADR 0008 CI pipeline changes)
    );

    // ── Delete happy path ────────────────────────────────────────────────────

    testWidgets(
      'owner deletes own note → file removed from list, noteCount decremented',
      (tester) async {
        // TODO(CI): Implement once emulators are seeded.
        //
        // Steps:
        //   1. Sign in as a KMUTT-domain user (the file owner).
        //   2. Navigate to AllFilesScreen for a session that already has one note
        //      (seeded in Firestore emulator).
        //   3. Tap the delete button on the note tile.
        //   4. pumpAndSettle(Duration(seconds: 5)) — delete batch commits.
        //   5. Expect: the note tile disappears from the ListView.
        //   6. Expect: noteCount on the session document == 0.
        //   7. Expect: the Storage object at the storageRef path returns 404
        //      (deletion propagated to Storage after Firestore batch).
      },
      skip: true, // Pending CI emulator configuration (ADR 0008 CI pipeline changes)
    );

    // ── Permission denied path ───────────────────────────────────────────────

    testWidgets(
      'non-owner non-host cannot delete note → NoteError.permissionDenied',
      (tester) async {
        // TODO(CI): Implement once emulators are seeded.
        //
        // Steps:
        //   1. Sign in as a KMUTT-domain user who is neither the host nor the
        //      file owner.
        //   2. The delete button should not be rendered (verified in widget tests).
        //      This integration test verifies the Firestore rule rejection
        //      by calling deleteNote directly via the repository.
        //   3. Expect: the Firestore WriteBatch returns permission-denied.
        //   4. Expect: the NoteRepository maps it to NoteError.permissionDenied.
      },
      skip: true, // Pending CI emulator configuration (ADR 0008 CI pipeline changes)
    );

    // ── Cap enforcement path ─────────────────────────────────────────────────

    testWidgets(
      'upload when noteCount == 50 → NoteError.sessionCapReached',
      (tester) async {
        // TODO(CI): Implement once emulators are seeded.
        //
        // Steps:
        //   1. Sign in as a KMUTT-domain user.
        //   2. Use a session seeded with noteCount = 50 in Firestore emulator.
        //   3. Attempt to upload a valid PDF.
        //   4. Expect: the WriteBatch fails (Firestore rules reject the increment
        //      to 51 via the getAfter(...) cap check in ADR 0001).
        //   5. Expect: the repository surfaces NoteError.permissionDenied.
        //      (permission-denied cannot be distinguished from auth failures at
        //      the SDK level — see NoteRepositoryImpl.uploadNote comment.)
      },
      skip: true, // Pending CI emulator configuration (ADR 0008 CI pipeline changes)
    );
  });
}
