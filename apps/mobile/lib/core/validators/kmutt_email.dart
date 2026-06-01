/// Shared KMUTT email domain validator.
///
/// Accepted domains: `mail.kmutt.ac.th` and `kmutt.ac.th`.
/// Case-sensitive — no `/i` flag. Matches ADR 0001 / ADR 0002 spec.
/// Local-part must contain no `@` characters (guards against double-@ injection).
///
/// Pure Dart — zero Flutter or Firebase imports.
const String kmuttEmailPattern =
    r'^[^\s@]+@(mail\.kmutt\.ac\.th|kmutt\.ac\.th)$';
