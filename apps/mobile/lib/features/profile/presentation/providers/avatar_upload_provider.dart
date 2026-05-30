import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/profile/data/datasources/avatar_datasource.dart';
import 'package:mobile/features/profile/data/datasources/profile_datasource.dart';
import 'package:mobile/features/profile/data/repositories/avatar_repository_impl.dart';
import 'package:mobile/features/profile/domain/repositories/avatar_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatar_upload_provider.g.dart';

/// Provides the [AvatarRepository] implementation wired to Firebase Storage
/// and Firestore.
///
/// [AvatarDatasource.withDefaultStorage] and
/// [ProfileDatasource] are instantiated inside the provider body so that
/// neither `firebase_storage` nor `cloud_firestore` need to appear in any
/// presentation-layer file that only reads from this provider.
@riverpod
AvatarRepository avatarRepository(Ref ref) {
  return AvatarRepositoryImpl(
    AvatarDatasource.withDefaultStorage(),
    ProfileDatasource.withDefaultFirestore(),
  );
}

/// Notifier that drives the avatar pick-and-upload flow.
///
/// State is [AsyncValue<void>]:
/// - [AsyncData] — idle (initial) or upload completed successfully.
/// - [AsyncLoading] — upload in progress.
/// - [AsyncError] — upload failed; presentation layer should show a snackbar
///   and revert the optimistic UI.
@riverpod
class AvatarUpload extends _$AvatarUpload {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Triggers the full pick → compress → upload → Firestore write flow.
  Future<void> pickAndUpload(String uid) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(avatarRepositoryProvider).pickAndUpload(uid),
    );
  }
}

/// Streams optimistic local preview bytes for [uid] while an avatar upload
/// is in progress. Emits `null` when no upload is active.
@riverpod
Stream<List<int>?> localBytesStream(Ref ref, String uid) =>
    ref.watch(avatarRepositoryProvider).watchLocalPreviewBytes(uid);
