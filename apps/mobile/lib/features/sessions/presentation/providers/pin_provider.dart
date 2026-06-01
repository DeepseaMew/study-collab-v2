import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the PIN entered by the user on the Home screen after a successful
/// findSessionByPin lookup. Cleared by [_NotJoinedActionsState._requestJoin]
/// once the join request completes (success or failure), so the PIN does not
/// persist in memory longer than necessary and is never placed in GoRouter
/// extra (which go_router serialises to window.history.state on Flutter Web).
final joinPinProvider = StateProvider<String?>((ref) => null);
