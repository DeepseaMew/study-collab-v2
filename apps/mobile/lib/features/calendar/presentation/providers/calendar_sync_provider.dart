import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mobile/core/feature_flags.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/calendar/data/datasources/gcal_datasource.dart';
import 'package:mobile/features/calendar/data/repositories/calendar_sync_repository_impl.dart';
import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/calendar/domain/usecases/connect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/disconnect_gcal_usecase.dart';
import 'package:mobile/features/calendar/domain/usecases/sync_gcal_usecase.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/user_repository_impl.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_sync_provider.g.dart';

/// Provides the [CalendarSyncRepository] wired to Google Sign-In.
@riverpod
CalendarSyncRepository calendarSyncRepository(CalendarSyncRepositoryRef ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('calendarSyncRepository: no authenticated user');
  return CalendarSyncRepositoryImpl(
    googleSignIn: GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/calendar.events'],
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
  AsyncValue<SyncResult?> build() => const AsyncData(null);

  /// Connects the current user's Google Calendar account.
  Future<void> connect() async {
    if (!FeatureFlags.gcalSyncEnabled) return;
    state = const AsyncLoading();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      state = AsyncError(StateError('No authenticated user'), StackTrace.current);
      return;
    }
    state = await AsyncValue.guard(() async {
      final usecase = ConnectGCalUseCase(
        syncRepository: ref.read(calendarSyncRepositoryProvider),
        userRepository: UserRepositoryImpl(ProfileDatasource.withDefaultFirestore()),
        uid: uid,
      );
      await usecase();
      appLogger.info('gcal_sync: connected');
      return null;
    });
  }

  /// Disconnects the Google Calendar sync.
  Future<void> disconnect() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await DisconnectGCalUseCase(ref.read(calendarSyncRepositoryProvider))
          .call();
      appLogger.info('gcal_sync: disconnected');
      return null;
    });
  }

  /// Syncs [sessions] to the connected Google Calendar.
  Future<void> syncNow(List<SessionEntity> sessions) async {
    if (!FeatureFlags.gcalSyncEnabled) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SyncGCalUseCase(ref.read(calendarSyncRepositoryProvider))
          .call(sessions),
    );
  }
}
