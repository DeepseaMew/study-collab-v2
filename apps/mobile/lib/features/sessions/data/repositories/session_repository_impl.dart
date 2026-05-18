import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/domain/entities/user_entity.dart';
import 'package:mobile/features/sessions/data/datasources/session_datasource.dart';
import 'package:mobile/features/sessions/domain/entities/session_entity.dart';
import 'package:mobile/features/sessions/domain/repositories/session_repository.dart';

/// Firestore implementation of [SessionRepository].
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._datasource);

  final SessionDatasource _datasource;

  @override
  Stream<SessionEntity?> watchSession(String sessionId) {
    return _datasource
        .watchSession(sessionId)
        .map((model) => model?.toEntity());
  }

  @override
  Stream<List<SessionEntity>> watchPublicSessions() {
    return _datasource
        .watchPublicSessions()
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<List<UserEntity>> watchMembers(String sessionId) {
    // Watch the session document for memberUids, then read each user doc.
    // This is a best-effort implementation: members missing from Firestore
    // are silently omitted.
    return _datasource.watchSession(sessionId).asyncMap((model) async {
      if (model == null) return <UserEntity>[];
      final uids = model.memberUids;
      final futures = uids.map((uid) => _datasource.readUserDoc(uid));
      final results = await Future.wait(futures);
      final users = <UserEntity>[];
      for (var i = 0; i < uids.length; i++) {
        final data = results[i];
        if (data == null) continue;
        try {
          users.add(_userFromMap(uids[i], data));
        } catch (e) {
          appLogger.warning(
            'Could not parse user document for member',
            extra: {'error': e.toString()},
          );
          // Non-fatal: skip member rather than failing the whole stream.
        }
      }
      return users;
    });
  }

  @override
  Future<void> createSession(
    SessionEntity session, {
    String? plainTextPin,
  }) async {
    // Read host display data once for denormalization (ADR 0003 sub-decision 3).
    final hostData = await _datasource.readUserDoc(session.hostUid);
    final hostDisplayName =
        (hostData?['displayName'] as String?) ?? session.hostDisplayName;
    final hostPhotoUrl =
        (hostData?['photoUrl'] as String?) ?? session.hostPhotoUrl;
    final hostFaculty =
        (hostData?['faculty'] as String?) ?? session.hostFaculty;

    final data = <String, dynamic>{
      'hostUid': session.hostUid,
      'hostFaculty': hostFaculty,
      'title': session.title,
      'description': session.description,
      'hashtags': session.hashtags,
      'academicLevel': session.academicLevel,
      'studentYear': session.studentYear,
      'visibility': session.visibility,
      'memberUids': [session.hostUid],
      'noteCount': 0,
      'status': 'scheduled',
      'scheduledAt': Timestamp.fromDate(session.scheduledAt),
      if (session.scheduledEndAt != null)
        'scheduledEndAt': Timestamp.fromDate(session.scheduledEndAt!),
      'location': session.location,
      'capacity': session.capacity,
      'hostDisplayName': hostDisplayName,
      'hostPhotoUrl': hostPhotoUrl,
    };

    if (session.visibility == 'private' && plainTextPin != null) {
      data['pin'] = plainTextPin;
    }

    await _datasource.createSession(data);
    appLogger.info('Session document created via repository');
  }

  @override
  Future<void> editSession(
    String sessionId,
    String callerUid,
    Map<String, dynamic> updates,
  ) async {
    final session = await _datasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException('Only the host may edit this session.');
    }

    // Convert DateTime to Timestamp if present.
    final firestoreUpdates = <String, dynamic>{};
    for (final entry in updates.entries) {
      if (entry.value is DateTime) {
        firestoreUpdates[entry.key] = Timestamp.fromDate(entry.value as DateTime);
      } else {
        firestoreUpdates[entry.key] = entry.value;
      }
    }

    await _datasource.updateSession(sessionId, firestoreUpdates);
  }

  @override
  Future<void> deleteSession(String sessionId, String callerUid) async {
    final session = await _datasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException(
        'Only the host may delete this session.',
      );
    }
    if (session.status != 'scheduled') {
      throw const ValidationException(
        'Only scheduled sessions may be deleted.',
      );
    }
    await _datasource.deleteSession(sessionId);
  }

  @override
  Future<void> endSession(String sessionId, String callerUid) async {
    final session = await _datasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException('Only the host may end this session.');
    }
    await _datasource.updateSession(sessionId, {
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> leaveSession(String sessionId, String uid) async {
    final session = await _datasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid == uid) {
      throw const AuthorisationException(
        'Host cannot leave their own session.',
      );
    }
    await _datasource.updateSession(sessionId, {
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<String?> fetchPin(String sessionId, String callerUid) async {
    final session = await _datasource.watchSession(sessionId).first;
    if (session == null) {
      throw const NotFoundException('Session not found.');
    }
    if (session.hostUid != callerUid) {
      throw const AuthorisationException('Only the host may view the PIN.');
    }
    return _datasource.fetchSessionPin(sessionId);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  UserEntity _userFromMap(String uid, Map<String, dynamic> data) {
    return UserEntity(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      // fullName, email, bio not needed for member display — drop to avoid
      // propagating PII through in-memory objects.
      fullName: '',
      email: '',
      photoUrl: data['photoUrl'] as String?,
      hasHostedBefore: (data['hasHostedBefore'] as bool?) ?? false,
      studentYear: (data['studentYear'] as int?) ?? 1,
      academicLevel: (data['academicLevel'] as String?) ?? 'undergraduate',
      faculty: (data['faculty'] as String?) ?? '',
      profileScore: ((data['profileScore'] as num?) ?? 0.0).toDouble(),
    );
  }
}
