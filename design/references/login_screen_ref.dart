// DESIGN REFERENCE ONLY — do not run, do not import.
// Use this file to understand layout structure, spacing, and widget composition.
// Rebuild from scratch using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// All state, providers, and imports must follow CLAUDE.md conventions.

// ── LoginScreen ──────────────────────────────────────────────────────────────
//
// StatefulWidget (needs ConsumerStatefulWidget in implementation).
//
// State:
//   - email controller
//   - password controller (obscured, toggle visibility)
//   - isLoading bool — disables button and shows spinner while signing in
//   - error string? — shown in error banner when not null
//
// On submit:
//   - validate form
//   - call auth use case with email + password
//   - on success: navigate to /home
//   - on AuthException: show error banner with message
//   - always: set isLoading false on completion

// Scaffold(
//   backgroundColor: [theme background — light purple tint],
//
//   body: Stack(
//     children: [
//
//       // Decorative circle — top right, partially off screen
//       Positioned(top: -70, right: -70,
//         child: Container(
//           width: 220, height: 220,
//           shape: BoxShape.circle,
//           color: [accent color at 8% opacity],
//         ),
//       ),
//
//       // Decorative circle — bottom left, partially off screen
//       Positioned(bottom: -90, left: -90,
//         child: Container(
//           width: 260, height: 260,
//           shape: BoxShape.circle,
//           color: [accent color at 8% opacity],
//         ),
//       ),
//
//       // Main content
//       SafeArea(
//         child: SingleChildScrollView(
//           padding: horizontal 24, vertical 48,
//           child: Form(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//
//                 // Logo — centered, 60x60
//                 Center(child: Image.asset('assets/images/Logo.svg', 60x60)),
//                 SizedBox(height: 20),
//
//                 // Headline
//                 Text('Welcome back!',
//                   textAlign: center, fontSize: 24, fontWeight: w700),
//                 SizedBox(height: 6),
//                 Text('Sign in to continue studying',
//                   textAlign: center, fontSize: 14, hint color),
//                 SizedBox(height: 36),
//
//                 // Error banner (visible only when error is not null)
//                 Container(
//                   padding: horizontal 14, vertical 10,
//                   decoration: BoxDecoration(
//                     color: [error color at 8% opacity],
//                     borderRadius: 8,
//                     border: Border.all([error color at 30% opacity]),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.error_outline, size: 16, error color),
//                       SizedBox(width: 8),
//                       Expanded(child: Text(error, fontSize: 13, error color)),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 16),   // only shown with banner
//
//                 // Email label
//                 Text('Email address',
//                   fontSize: 12, fontWeight: w600, [accent muted color]),
//                 SizedBox(height: 6),
//
//                 // Email field
//                 TextFormField(
//                   keyboardType: emailAddress,
//                   hint: 'You@mail.kmutt.ac.th',
//                   filled: true, fillColor: white,
//                   contentPadding: horizontal 16, vertical 14,
//                   border radius: 12 on all border states,
//                   // border: [theme border color]
//                   // focusedBorder: [accent color, width 2]
//                   // errorBorder: [error color]
//                   // focusedErrorBorder: [error color, width 2]
//                   validator: → KMUTT email domain validation,
//                 ),
//                 SizedBox(height: 16),
//
//                 // Password label
//                 Text('Password',
//                   fontSize: 12, fontWeight: w600, [accent muted color]),
//                 SizedBox(height: 6),
//
//                 // Password field
//                 TextFormField(
//                   obscureText: [toggle state],
//                   hint: '••••••••',
//                   filled: true, fillColor: white,
//                   contentPadding: horizontal 16, vertical 14,
//                   suffixIcon: IconButton(
//                     // Icons.visibility_off_outlined when obscured
//                     // Icons.visibility_outlined when visible
//                     // size: 20, hint color
//                     onPressed: → toggle obscure state,
//                   ),
//                   border radius: 12 on all border states (same as email field),
//                   validator: → password validation,
//                 ),
//
//                 // Forgot password — right-aligned text button
//                 Align(alignment: centerRight,
//                   child: TextButton(
//                     padding: vertical 8, shrinkWrap tap target,
//                     child: Text('Forgot password?',
//                       color: accent, fontSize: 13, fontWeight: w500),
//                     onPressed: → show snackbar 'Password reset coming soon',
//                   ),
//                 ),
//                 SizedBox(height: 8),
//
//                 // Sign In button — full width, height 50
//                 ElevatedButton(
//                   style: backgroundColor accent, foreground white,
//                     borderRadius: 12, elevation: 0,
//                   onPressed: isLoading ? null : → signIn,
//                   child: [if loading → CircularProgressIndicator(size 20x20, strokeWidth 2)]
//                          [else → Text('Sign In', fontSize 15, fontWeight w600)],
//                 ),
//                 SizedBox(height: 28),
//
//                 // Sign up link — centered row
//                 Row(mainAxisAlignment: center,
//                   children: [
//                     Text("Don't have an account? ",
//                       color: hint, fontSize: 14),
//                     GestureDetector(
//                       onTap: → navigate to /signup,
//                       child: Text('Create Account',
//                         color: accent, fontSize: 14, fontWeight: w600),
//                     ),
//                   ],
//                 ),
//
//               ],
//             ),
//           ),
//         ),
//       ),
//
//     ],
//   ),
// )
