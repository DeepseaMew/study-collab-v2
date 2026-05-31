// DESIGN REFERENCE ONLY — do not run, do not import.
// Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// Follow CLAUDE.md conventions.

// ══════════════════════════════════════════════════════════════════════════════
// SettingsScreen — ConsumerStatefulWidget
// ══════════════════════════════════════════════════════════════════════════════

// class SettingsScreen extends ConsumerStatefulWidget {
//   const SettingsScreen({super.key});
// }

// class _SettingsScreenState extends ConsumerState<SettingsScreen> {
//
//   // [State: bool _allNotifications = true]
//   // [State: bool _joinAlerts       = true]
//   // [State: bool _sessionReminders = true]
//   // [State: bool _friendRequests   = true]
//
//   // [Color const — toggle switch track active: Color(0xFF5186CD) — hardcoded, not in AppColors]
//
//   // ── build() ──────────────────────────────────────────────────────────────
//
//   // Scaffold(
//   //   backgroundColor: AppColors.background — #FFFFFF,
//   //   appBar: AppBar(
//   //     title: Text('Settings'),
//   //   ),
//   //   body: ListView(
//   //     padding: EdgeInsets.fromLTRB(16, 16, 16, 40),
//   //     children: [
//   //
//   //       ── Profile ────────────────────────────────────────────────────────
//   //
//   //       _SectionCard(
//   //         children: [
//   //           ListTile(
//   //             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//   //             leading: CircleAvatar(
//   //               radius: 28,
//   //               backgroundColor: AppColors.accent — #894DEF at 15% opacity,
//   //               backgroundImage: [NetworkImage from user.profilePhotoUrl when non-empty],
//   //               child: [if no photo or photo url is empty]
//   //                 Text(
//   //                   user.username[0].toUpperCase() — fallback '?',
//   //                   fontSize: 20,
//   //                   fontWeight: FontWeight.w700,
//   //                   color: AppColors.accent — #894DEF,
//   //                 ),
//   //             ),
//   //             title: Text(
//   //               user?.username ?? 'Guest',
//   //               style: tt.titleLarge,
//   //             ),
//   //             subtitle: Text(
//   //               user?.email ?? '',
//   //               style: tt.bodyMedium,
//   //               color: AppColors.hint — #767676,
//   //             ),
//   //             trailing: TextButton(
//   //               // [Action: open EditProfileSheet as modalBottomSheet,
//   //               //          isScrollControlled: true, backgroundColor: Colors.transparent]
//   //               // [Guard: do nothing if currentUser is null]
//   //               child: Text(
//   //                 'Edit Profile',
//   //                 color: AppColors.accent — #894DEF,
//   //                 fontSize: 13,
//   //               ),
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //
//   //       SizedBox(height: 24),
//   //
//   //       ── Notifications ───────────────────────────────────────────────────
//   //
//   //       _SectionLabel('Notifications'),
//   //       SizedBox(height: 8),
//   //       _SectionCard(
//   //         children: [
//   //           _ToggleTile(
//   //             title: 'All Notifications',
//   //             subtitle: 'Master toggle for all alerts',
//   //             // [State: value = _allNotifications]
//   //             // [Action: toggle _allNotifications;
//   //             //          if turned off → set _joinAlerts, _sessionReminders, _friendRequests = false]
//   //             color: Color(0xFF5186CD),
//   //           ),
//   //           _Divider(),
//   //           _ToggleTile(
//   //             title: 'Join Request Alerts',
//   //             subtitle: 'When someone requests to join your session',
//   //             // [State: value = _joinAlerts && _allNotifications]
//   //             // [Action: onChanged is null (disabled) when _allNotifications is false]
//   //             color: Color(0xFF5186CD),
//   //           ),
//   //           _Divider(),
//   //           _ToggleTile(
//   //             title: 'Session Reminders',
//   //             subtitle: 'Reminders before sessions start',
//   //             // [State: value = _sessionReminders && _allNotifications]
//   //             // [Action: onChanged is null (disabled) when _allNotifications is false]
//   //             color: Color(0xFF5186CD),
//   //           ),
//   //           _Divider(),
//   //           _ToggleTile(
//   //             title: 'Friend Requests',
//   //             subtitle: 'When someone sends you a friend request',
//   //             // [State: value = _friendRequests && _allNotifications]
//   //             // [Action: onChanged is null (disabled) when _allNotifications is false]
//   //             color: Color(0xFF5186CD),
//   //           ),
//   //         ],
//   //       ),
//   //
//   //       SizedBox(height: 24),
//   //
//   //       ── Account ─────────────────────────────────────────────────────────
//   //
//   //       _SectionLabel('Account'),
//   //       SizedBox(height: 8),
//   //       _SectionCard(
//   //         children: [
//   //           ListTile(
//   //             leading: Icon(Icons.lock_outline, color: AppColors.text — #1A1A2E),
//   //             title: Text(
//   //               'Change Password',
//   //               style: tt.bodyMedium,
//   //               fontWeight: FontWeight.w500,
//   //             ),
//   //             trailing: Icon(Icons.chevron_right, color: AppColors.hint — #767676),
//   //             // [Action: _showChangePassword(context)]
//   //           ),
//   //           _Divider(),
//   //           ListTile(
//   //             leading: Icon(Icons.logout, color: AppColors.error — #CC0000),
//   //             title: Text(
//   //               'Sign Out',
//   //               style: tt.bodyMedium,
//   //               color: AppColors.error — #CC0000,
//   //               fontWeight: FontWeight.w500,
//   //             ),
//   //             // [Action: _showSignOut(context)]
//   //           ),
//   //         ],
//   //       ),
//   //
//   //     ],
//   //   ),
//   // )

//   // ── _showChangePassword() ─────────────────────────────────────────────────
//   // showDialog → _ChangePasswordDialog

//   // ── _showSignOut() ────────────────────────────────────────────────────────
//   // AlertDialog(
//   //   title: Text('Sign Out'),
//   //   content: Text('Are you sure you want to sign out?'),
//   //   actions: [
//   //     TextButton('Cancel') → Navigator.pop,
//   //     TextButton(
//   //       'Sign Out',
//   //       foregroundColor: AppColors.error — #CC0000,
//   //       // [Action: call authService.signOut(), then context.go('/login')]
//   //       // [Error: SnackBar 'Could not sign out. Please try again.',
//   //       //         backgroundColor: AppColors.error — #CC0000]
//   //     ),
//   //   ],
//   // )

// }

// ══════════════════════════════════════════════════════════════════════════════
// _SectionLabel — StatelessWidget
// ══════════════════════════════════════════════════════════════════════════════

// // Text(text, style: tt.titleLarge)

// ══════════════════════════════════════════════════════════════════════════════
// _SectionCard — StatelessWidget
// ══════════════════════════════════════════════════════════════════════════════

// // Container(
// //   decoration: BoxDecoration(
// //     color: AppColors.surface — #F8F7FF,
// //     borderRadius: BorderRadius.circular(12),
// //     border: Border.all(color: AppColors.border — #D4D4D4),
// //   ),
// //   clipBehavior: Clip.antiAlias,
// //   child: Column(mainAxisSize: MainAxisSize.min, children: children),
// // )

// ══════════════════════════════════════════════════════════════════════════════
// _Divider — StatelessWidget
// ══════════════════════════════════════════════════════════════════════════════

// // Divider(
// //   height: 1,
// //   indent: 16,
// //   endIndent: 16,
// //   color: AppColors.border — #D4D4D4,
// // )

// ══════════════════════════════════════════════════════════════════════════════
// _ToggleTile — StatelessWidget
// ══════════════════════════════════════════════════════════════════════════════

// // Props: title, subtitle, value, color, onChanged (nullable — null = disabled)
// // ListTile(
// //   title: Text(title, style: tt.bodyMedium, fontWeight: FontWeight.w500),
// //   subtitle: Text(subtitle, style: tt.labelSmall, color: AppColors.hint — #767676),
// //   trailing: Switch(
// //     thumbColor: always Colors.white,
// //     trackColor: selected → color, unselected → AppColors.border — #D4D4D4,
// //     trackOutlineColor: selected → color, unselected → AppColors.border — #D4D4D4,
// //   ),
// // )

// ══════════════════════════════════════════════════════════════════════════════
// _ChangePasswordDialog — StatefulWidget / AlertDialog
// ══════════════════════════════════════════════════════════════════════════════

// // [State: TextEditingController _currentCtrl]
// // [State: TextEditingController _newCtrl]
// // [State: TextEditingController _confirmCtrl]
// // [State: bool _obscureCurrent = true]
// // [State: bool _obscureNew     = true]
// // [State: bool _obscureConfirm = true]
// // [Lifecycle: dispose all three controllers]
//
// // AlertDialog(
// //   title: Text('Change Password'),
// //   content: Column(
// //     mainAxisSize: MainAxisSize.min,
// //     children: [
// //       _PwField(hint: 'Current password',      obscure: _obscureCurrent),
// //       SizedBox(height: 12),
// //       _PwField(hint: 'New password',          obscure: _obscureNew),
// //       SizedBox(height: 12),
// //       _PwField(hint: 'Confirm new password',  obscure: _obscureConfirm),
// //     ],
// //   ),
// //   actions: [
// //     TextButton('Cancel') → Navigator.pop,
// //     ElevatedButton(
// //       'Save',
// //       minimumSize: Size(80, 40),
// //       // [Validation: if _newCtrl.text is empty → return early]
// //       // [Validation: if _newCtrl.text != _confirmCtrl.text →
// //       //              SnackBar 'Passwords do not match',
// //       //              backgroundColor: AppColors.error — #CC0000]
// //       // [Action on success: Navigator.pop +
// //       //              SnackBar 'Password changed successfully!',
// //       //              backgroundColor: AppColors.success — #38A169]
// //       // [TODO: wire to FirebaseAuth.currentUser?.updatePassword — requires recent login / re-auth]
// //     ),
// //   ],
// // )

// ══════════════════════════════════════════════════════════════════════════════
// _PwField — StatelessWidget
// ══════════════════════════════════════════════════════════════════════════════

// // Props: ctrl (TextEditingController), hint (String), obscure (bool), onToggle (VoidCallback)
// // TextField(
// //   controller: ctrl,
// //   obscureText: obscure,
// //   decoration: InputDecoration(
// //     hintText: hint,
// //     suffixIcon: IconButton(
// //       icon: Icon(
// //         obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
// //         size: 18,
// //       ),
// //       // [Action: onPressed → onToggle() to flip obscure state]
// //     ),
// //   ),
// // )
