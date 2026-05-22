import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:mobile/core/errors/calendar_sync_error.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/calendar/data/datasources/gcal_datasource.dart';
import 'package:mobile/features/calendar/domain/entities/sync_result.dart';
import 'package:mobile/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';

/// Google Sign-In + Calendar API implementation of [CalendarSyncRepository].
class CalendarSyncRepositoryImpl implements CalendarSyncRepository {
  CalendarSyncRepositoryImpl({
    required GoogleSignIn googleSignIn,
    required FlutterSecureStorage secureStorage,
    required GcalDatasource Function(CalendarApi) datasourceFactory,
    required String uid,
  })  : _googleSignIn = googleSignIn,
        _secureStorage = secureStorage,
        _datasourceFactory = datasourceFactory,
        _uid = uid;

  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  final GcalDatasource Function(CalendarApi) _datasourceFactory;
  final String _uid;

  static const _lastSyncKey = 'gcal_last_sync_';

  @override
  Future<bool> isConnected() async {
    final account = await _googleSignIn.signInSilently();
    return account != null;
  }

  @override
  Future<void> connect(String expectedEmail) async {
    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } catch (e) {
      appLogger.warning(
        'gcal_sync: user cancelled consent screen',
        extra: {'reason': e.toString()},
      );
      throw CancelledError();
    }
    if (account == null) {
      appLogger.warning('gcal_sync: user cancelled consent screen');
      throw CancelledError();
    }
    if (account.email.toLowerCase() != expectedEmail.toLowerCase()) {
      appLogger.warning('gcal_sync: email mismatch; aborting connect');
      await _googleSignIn.signOut();
      throw EmailMismatchError();
    }
    final hasScope = await _googleSignIn.requestScopes(
      ['https://www.googleapis.com/auth/calendar.events'],
    );
    if (!hasScope) {
      appLogger.warning('gcal_sync: calendar scope denied');
      await _googleSignIn.signOut();
      throw CancelledError();
    }
  }

  @override
  Future<void> disconnect() async {
    // disconnect() revokes the server-side OAuth grant AND clears the local session.
    // signOut() alone would leave the grant alive; disconnect() is the correct call.
    await _googleSignIn.disconnect();
    await _secureStorage.delete(key: '$_lastSyncKey$_uid');
  }

  @override
  Future<SyncResult> syncSessions(List<SessionEntity> sessions) async {
    final account = _googleSignIn.currentUser;
    if (account == null) throw CancelledError();
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw ApiFailureError('no authenticated client');
    }
    final calendarApi = CalendarApi(httpClient);
    final datasource = _datasourceFactory(calendarApi);
    final result = await datasource.syncSessions(sessions);
    await _secureStorage.write(
      key: '$_lastSyncKey$_uid',
      value: DateTime.now().toIso8601String(),
    );
    return result;
  }
}
