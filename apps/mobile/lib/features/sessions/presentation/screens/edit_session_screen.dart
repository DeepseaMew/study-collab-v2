import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/logger.dart';
import 'package:mobile/features/auth/presentation/providers/firebase_auth_state_provider.dart';
import 'package:mobile/features/sessions/presentation/providers/session_provider.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_form.dart';
import 'package:mobile/shared/theme/app_colors.dart';

/// Screen for editing an existing session.
///
/// Loads the session via [sessionStreamProvider], guards non-hosts,
/// and wraps [SessionForm] with a Delete button injected via [bottomExtra].
///
/// Route: `/sessions/:id/edit`
class EditSessionScreen extends ConsumerWidget {
  const EditSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStreamProvider(sessionId));
    final me = ref.watch(firebaseAuthStateProvider).valueOrNull;

    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) {
        appLogger.error(
          'EditSessionScreen failed to load session',
          exception: e,
          stackTrace: st,
          extra: {'sessionId': sessionId},
        );
        return _ErrorScaffold(message: e.toString());
      },
      data: (session) {
        if (session == null) {
          return const _ErrorScaffold(message: 'Session not found.');
        }

        if (me == null || me.uid != session.hostUid) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.background,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.text,
                ),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Edit Session',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: const Center(
              child: Text(
                'You are not authorised to edit this session.',
                style: TextStyle(color: AppColors.hint),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SessionForm(
          isEditing: true,
          initialSession: session,
          bottomExtra: _DeleteSessionButton(sessionId: sessionId),
        );
      },
    );
  }
}

// ── Delete button ─────────────────────────────────────────────────────────────

class _DeleteSessionButton extends StatelessWidget {
  const _DeleteSessionButton({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _DeleteDialog(sessionId: sessionId),
        ),
        child: const Text(
          'Delete Session',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────

class _DeleteDialog extends ConsumerStatefulWidget {
  const _DeleteDialog({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    final me = ref.read(firebaseAuthStateProvider).valueOrNull;
    if (me == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _deleting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .deleteSession(widget.sessionId, me.uid);
      if (mounted) {
        Navigator.pop(context); // close dialog
        context.pop(); // go back to previous screen
      }
    } catch (e, st) {
      appLogger.error(
        'Delete session failed',
        exception: e,
        stackTrace: st,
        extra: {'sessionId': widget.sessionId},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Session',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'This will permanently delete the session and remove all members. '
        'This action cannot be undone.',
        style: TextStyle(color: AppColors.hint, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.hint)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(80, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Error scaffold ────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Session',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.hint),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.hint, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
