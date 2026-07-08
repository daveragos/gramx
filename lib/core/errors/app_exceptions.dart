class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, [this.cause]);

  @override
  String toString() => 'AppException: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);

  @override
  String toString() => 'DatabaseException: $message';
}

class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(super.message, [super.cause, this.statusCode]);

  @override
  String toString() => 'NetworkException: $message (status: $statusCode)';
}

class SyncException extends AppException {
  const SyncException(super.message, [super.cause]);

  @override
  String toString() => 'SyncException: $message';
}
