import 'package:mobile/features/note_sharing/domain/entities/note_entity.dart';
import 'package:mobile/features/note_sharing/domain/usecases/fetch_notes_page_usecase.dart';
import 'package:mobile/features/note_sharing/presentation/providers/note_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'paginated_notes_provider.g.dart';

/// State record for [PaginatedNotesNotifier].
typedef PaginatedNotesState = ({List<NoteEntity> notes, bool hasMore});

/// Async notifier for cursor-based note pagination in [AllFilesScreen]
/// (ADR 0008).
///
/// On [build]: loads the first page (limit 20).
/// [fetchNextPage]: loads the next page using the `uploadedAt` of the last
///   note as the cursor.
/// [refresh]: resets to the first page.
@riverpod
class PaginatedNotesNotifier extends _$PaginatedNotesNotifier {
  static const int _pageSize = 20;

  @override
  Future<PaginatedNotesState> build(String sessionId) async {
    return _loadPage([]);
  }

  /// Loads the next page and appends it to the current list.
  /// No-ops if [hasMore] is already false.
  Future<void> fetchNextPage() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore) return;

    final cursor = current.notes.isNotEmpty
        ? current.notes.last.uploadedAt
        : null;

    final repository = ref.read(noteRepositoryProvider);
    final useCase = FetchNotesPageUseCase(repository);
    final nextPage = await useCase.call(sessionId, startAfter: cursor);

    state = AsyncData((
      notes: [...current.notes, ...nextPage],
      hasMore: nextPage.length == _pageSize,
    ));
  }

  /// Resets state to the first page.
  Future<void> refresh() async {
    state = const AsyncLoading<PaginatedNotesState>();
    state = await AsyncValue.guard(() => _loadPage([]));
  }

  Future<PaginatedNotesState> _loadPage(List<NoteEntity> existing) async {
    final repository = ref.read(noteRepositoryProvider);
    final useCase = FetchNotesPageUseCase(repository);
    final page = await useCase.call(sessionId);
    return (notes: [...existing, ...page], hasMore: page.length == _pageSize);
  }
}
