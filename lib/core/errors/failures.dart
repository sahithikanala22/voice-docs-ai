/// User-facing failure reasons. Domain/presentation code switches on this
/// instead of catching data-layer exception types directly, so the UI never
/// needs to know whether a failure came from a plugin, a socket, or disk.
enum FailureType { permissionDenied, network, notAvailable, unknown }

class Failure {
  const Failure(this.type, this.message);

  final FailureType type;
  final String message;

  factory Failure.permissionDenied([String message = 'Permission was denied.']) =>
      Failure(FailureType.permissionDenied, message);

  factory Failure.network([String message = 'A network error occurred.']) =>
      Failure(FailureType.network, message);

  factory Failure.notAvailable([String message = 'This feature is not available on this device.']) =>
      Failure(FailureType.notAvailable, message);

  factory Failure.unknown([String message = 'Something went wrong.']) =>
      Failure(FailureType.unknown, message);

  @override
  String toString() => 'Failure($type, $message)';
}
