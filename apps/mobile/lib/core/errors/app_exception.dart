/// Sealed error hierarchy for Study Collab.
///
/// Domain errors are defined here and propagated through the repository layer.
/// Never throw raw strings — always throw a subclass of [AppException].
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firestore or network read/write failed.
final class DataException extends AppException {
  const DataException(super.message);
}

/// The caller is not authorised to perform the requested operation.
final class AuthorisationException extends AppException {
  const AuthorisationException(super.message);
}

/// A required resource was not found.
final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// A domain validation rule was violated.
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// The session PIN provided by the user is incorrect.
final class InvalidPinException extends AppException {
  const InvalidPinException(super.message);
}

/// An operation was attempted while the device is offline.
final class OfflineException extends AppException {
  const OfflineException(super.message);
}
