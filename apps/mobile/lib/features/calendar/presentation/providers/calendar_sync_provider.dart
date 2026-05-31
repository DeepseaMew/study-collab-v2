import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/calendar/data/datasources/gcal_datasource.dart';
import 'package:mobile/features/calendar/data/repositories/calendar_sync_repository_impl.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_sessions_provider.dart';
import 'package:mobile/features/calendar/presentation/providers/calendar_window_provider.dart';
import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/calendar/domain/usecases/connect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/disconnect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/sync_gcal_usecase.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/user_repository_impl.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
part 'calendar_sync_provider.g.dart';

/// Provides the [CalendarSyncRepository] wired to Google Sign-In.
@riverpod
CalendarSyncRepository calendarSyncRepository(CalendarSyncRepositoryRef ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw StateError('calendarSyncRepository: no authenticated user');
  }
  const webClientId =
      '381478877763-norjr9uus1upro94tsv4gmskos6jgjon.apps.googleusercontent.com';
  return CalendarSyncRepositoryImpl(
    googleSignIn: GoogleSignIn(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
      scopes: const ['https://www.googleapis.com/auth/calendar.events'],
    ),
    secureStorage: const FlutterSecureStorage(),
    datasourceFactory: (CalendarApi api) => GcalDatasource(api),
    uid: uid,
  );
}

/// Manages the async state of GCal connect / sync / disconnect operations.
@riverpod
class CalendarSyncNotifier extends _$CalendarSyncNotifier {
  @override
  AsyncValue<SyncResult?> build() {
    if (FeatureFlags.gcalSyncEnabled) {
      Future.microtask(_tryReconnectSilently);
    }
    return const AsyncData(null);
  }

  /// Attempts a silent sign-in on startup. If the user previously connected,
  /// [GoogleSignIn.signInSilently] restores the session without a popup and
  /// [syncNow] pushes any pending sessions. If no previous session exists the
  /// method returns silently with no error and no state change.
  Future<void> _tryReconnectSilently() async {
    bool isConnected;
    try {
      isConnected = await ref
          .read(calendarSyncRepositoryProvider)
          .isConnected();
    } catch (e) {
      // Firebase or provider not yet initialised (e.g. in test environment).
      appLogger.info('gcal_sync: silent reconnect skipped — ${e.runtimeType}');
      return;
    }
    if (!isConnected) {
      appLogger.info('gcal_sync: no previous session — staying disconnected');
      return;
    }
    appLogger.info('gcal_sync: previous session restored — auto-syncing');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      appLogger.info('gcal_sync: no firebase user — skipping auto-sync');
      return;
    }
    final window = ref.read(calendarWindowProvider);
    List<SessionEntity> sessions;
    try {
      sessions = await ref
          .read(calendarSessionsProvider(uid, window.start, window.end).future)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      appLogger.info(
        'gcal_sync: sessions stream timed out — skipping auto-sync',
      );
      return;
    } catch (e) {
      appLogger.info('gcal_sync: sessions stream error — skipping auto-sync');
      return;
    }
    appLogger.info('gcal_sync: auto-sync sessions count=${sessions.length}');
    await syncNow(sessions);
  }

  /// Connects the current user's Google Calendar account, then immediately
  /// syncs [sessions] so they appear in Google Calendar straight away.
  Future<void> connect([List<SessionEntity> sessions = const []]) async {
    if (!FeatureFlags.gcalSyncEnabled) return;
    state = const AsyncLoading();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      state = AsyncError(
        StateError('No authenticated user'),
        StackTrace.current,
      );
      return;
    }
    state = await AsyncValue.guard(() async {
      final usecase = ConnectGCalUseCase(
        syncRepository: ref.read(calendarSyncRepositoryProvider),
        userRepository: UserRepositoryImpl(
          ProfileDatasource.withDefaultFirestore(),
        ),
        uid: uid,
      );
      await usecase();
      appLogger.info('gcal_sync: connected');
      return null;
    });
    // Auto-sync immediately after a successful connect so the user's sessions
    // appear in Google Calendar without requiring a separate manual sync.
    if (state is AsyncData) {
      appLogger.info('gcal_sync: auto-sync sessions count=${sessions.length}');
      await syncNow(sessions);
    }
  }

  /// Disconnects the Google Calendar sync.
  Future<void> disconnect() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await DisconnectGCalUseCase(
        ref.read(calendarSyncRepositoryProvider),
      ).call();
      appLogger.info('gcal_sync: disconnected');
      return null;
    });
  }

  /// Syncs [sessions] to the connected Google Calendar.
  Future<void> syncNow(List<SessionEntity> sessions) async {
    if (!FeatureFlags.gcalSyncEnabled) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SyncGCalUseCase(
        ref.read(calendarSyncRepositoryProvider),
      ).call(sessions),
    );
  }
}
