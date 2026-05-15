# strip-reference

Strip an old teammate `.dart` file into a layout-only design reference that
the Flutter Engineer can use to rebuild the screen in our stack.

---

## Prerequisite
`apps/mobile/lib/shared/theme/app_colors.dart` must exist and be filled
with hex values before running this skill.

---

## Usage
```
strip this file: [path to old .dart file]
```
or: 'make a reference from this', 'strip for reference', 'convert to reference'

**Example:**
```
strip this file: design/references/old/dashboard_screen.dart
```
Output: `design/references/dashboard_screen_ref.dart`

---

## What this does

**Strips**
- All imports
- All provider calls (`ref.watch`, `ref.read`, `ref.listen`)
- All service calls (`ref.read(xServiceProvider).method()`)
- All package-specific widgets (`badges.Badge`, `SvgPicture`, `XFile`, etc.)
- All `debugPrint`, `print`, log calls
- All TODO comments and mock logic
- All `dart:io`, `dart:async` imports
- All route name constants — replace with literal path string

**Keeps**
- Full widget tree structure and nesting
- All spacing, sizing, and layout values
- All `Icons.x` references
- All user-facing strings
- All state, action, and validation intent as comments
- All text style references (`tt.displaySmall`, `tt.bodyMedium`, etc.)

**Colors — never remove, always comment**
Resolve `AppColors.x` against `app_colors.dart`. Write token name + hex:
```
// AppColors.accent — #7C3AED
// AppColors.error — #EF4444 at 8% opacity
// Color(0xFFF0EEFF)
```
If token not found in `app_colors.dart`: write `hex unknown`.

**Package widgets — replace with intent comment**
```
badges.Badge(...)         →  // [Badge — show numeric dot when count > 0]
SvgPicture.asset(path)    →  // Image.asset(path, width: W, height: H)
CachedNetworkImage(url)   →  // [cached network image from url]
FileImage(File(path))     →  // [local file image from picked path]
```

---

## Steps

1. Read `apps/mobile/lib/shared/theme/app_colors.dart` — build color token map
2. Read the input file fully
3. Resolve all `AppColors.x` references against the token map
4. Strip in order: imports → providers → services → package widgets → debug/mock
5. Write output to `design/references/{filename}_ref.dart` with this header:
```
// DESIGN REFERENCE ONLY — do not run, do not import.
// Rebuild using our stack: Riverpod 2.x codegen, GoRouter, package imports.
// Colors match apps/mobile/lib/shared/theme/app_colors.dart.
// Follow CLAUDE.md conventions.
```
6. Print summary

---

## Summary output
```
Stripped: [imports, providers, packages]
Colors preserved: [tokens resolved, hardcoded hex kept]
Replaced: [package widget substitutions]
Kept: [layout, spacing, sizing, text styles, strings]
Output: design/references/{filename}_ref.dart
```