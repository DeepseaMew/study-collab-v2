import 'package:flutter/material.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_form.dart';

/// Thin wrapper that presents [SessionForm] in create mode.
///
/// Route: `/sessions/create`
class CreateSessionScreen extends StatelessWidget {
  const CreateSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SessionForm();
  }
}
