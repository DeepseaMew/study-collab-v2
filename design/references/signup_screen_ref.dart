// DESIGN REFERENCE ONLY — do not run, do not import.
// Use this file to understand layout structure, spacing, and widget composition.
// Rebuild from scratch using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// All state, providers, and imports must follow CLAUDE.md conventions.

// ── SignupScreen ─────────────────────────────────────────────────────────────
//
// StatefulWidget (needs ConsumerStatefulWidget in implementation).
//
// State:
//   - username controller
//   - email controller
//   - password controller (obscured, toggle visibility)
//   - confirm password controller (obscured, toggle visibility)
//   - avatarFile: local image file picked from gallery (nullable)
//   - isLoading bool
//   - error string?
//
// Avatar pick:
//   - open image gallery, imageQuality: 80, maxWidth: 512
//   - on pick: update avatarFile state
//   - on error: show error message
//
// On submit:
//   - validate form
//   - call auth use case with email, password, username
//   - on success: navigate to /home
//   - on AppException: show error banner
//   - always: set isLoading false

// Scaffold(
//   backgroundColor: [theme background],
//
//   appBar: AppBar(
//     leading: IconButton(
//       icon: Icons.arrow_back_ios_new_rounded, size: 20,
//       onPressed: → navigate to /login,
//     ),
//     title: Text('Create Account'),
//   ),
//
//   body: SafeArea(
//     child: SingleChildScrollView(
//       padding: horizontal 24, vertical 8,
//       child: Form(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SizedBox(height: 16),
//
//             // Avatar picker — centered
//             Center(
//               child: GestureDetector(
//                 onTap: → pickAvatar,
//                 child: Stack(
//                   clipBehavior: Clip.none,
//                   children: [
//
//                     // Avatar circle
//                     CircleAvatar(
//                       radius: 54,
//                       backgroundColor: [theme secondary],
//                       // if avatarFile != null: FileImage(avatarFile.path)
//                       // if avatarFile == null: Icon(Icons.person_rounded,
//                       //   size: 54, hint color)
//                     ),
//
//                     // Camera badge — bottom right of avatar
//                     Positioned(bottom: 0, right: 0,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: [accent],
//                           shape: BoxShape.circle,
//                           border: Border.all(white, width: 2),
//                         ),
//                         padding: all 6,
//                         child: Icon(Icons.camera_alt_rounded,
//                           size: 16, color: white),
//                       ),
//                     ),
//
//                   ],
//                 ),
//               ),
//             ),
//
//             // Caption below avatar — centered
//             Center(
//               child: Padding(top: 10, bottom: 28,
//                 child: Text('Tap to upload photo',
//                   style: tt.bodyMedium, hint color),
//               ),
//             ),
//
//             // Error banner (visible only when error is not null)
//             Container(
//               width: double.infinity,
//               padding: all 12,
//               decoration: BoxDecoration(
//                 color: [error at 8% opacity],
//                 borderRadius: 8,
//                 border: Border.all([error at 30% opacity]),
//               ),
//               child: Text(error, style: tt.bodyMedium error color),
//             ),
//             SizedBox(height: 16),   // only shown with banner
//
//             // Username field
//             TextFormField(
//               label: 'Username', hint: 'your_username',
//               prefixIcon: Icons.person_outline_rounded,
//               validator: → username validation,
//             ),
//             SizedBox(height: 16),
//
//             // Email field
//             TextFormField(
//               label: 'Email', hint: 'you@example.com',
//               prefixIcon: Icons.email_outlined,
//               keyboardType: emailAddress,
//               validator: → KMUTT email domain validation,
//             ),
//             SizedBox(height: 16),
//
//             // Password field
//             TextFormField(
//               label: 'Password', hint: '••••••••',
//               prefixIcon: Icons.lock_outline,
//               obscureText: [toggle state],
//               suffixIcon: IconButton(
//                 // Icons.visibility_outlined / Icons.visibility_off_outlined
//                 // size: 20, hint color
//                 onPressed: → toggle obscure,
//               ),
//               validator: → password validation,
//             ),
//             SizedBox(height: 16),
//
//             // Confirm password field
//             TextFormField(
//               label: 'Confirm Password', hint: '••••••••',
//               prefixIcon: Icons.lock_outline,
//               obscureText: [toggle state],
//               suffixIcon: IconButton(onPressed: → toggle obscure),
//               textInputAction: done,
//               onFieldSubmitted: → handleSignUp,
//               validator: → must match password field value,
//             ),
//             SizedBox(height: 32),
//
//             // Create Account button — full width
//             ElevatedButton(
//               onPressed: isLoading ? null : → handleSignUp,
//               child: [if loading → CircularProgressIndicator(20x20, strokeWidth 2)]
//                      [else → Text('Create Account')],
//             ),
//             SizedBox(height: 12),
//
//             // Back to sign in — full width outlined button
//             OutlinedButton(
//               onPressed: → navigate to /login,
//               child: Text('Already have an account? Sign In'),
//             ),
//             SizedBox(height: 32),
//
//           ],
//         ),
//       ),
//     ),
//   ),
// )
