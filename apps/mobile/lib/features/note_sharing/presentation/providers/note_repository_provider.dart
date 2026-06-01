import 'package:mobile/features/note_sharing/data/datasources/note_datasource.dart';
import 'package:mobile/features/note_sharing/data/repositories/note_repository_impl.dart';
import 'package:mobile/features/note_sharing/domain/repositories/note_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_repository_provider.g.dart';

/// Provides the [NoteRepository] implementation.
///
/// Kept alive for the entire app lifetime (no auto-dispose) so the stream
/// subscription in [notesProvider] does not restart on navigation.
@Riverpod(keepAlive: true)
NoteRepository noteRepository(NoteRepositoryRef ref) {
  return NoteRepositoryImpl(datasource: NoteDatasource());
}
