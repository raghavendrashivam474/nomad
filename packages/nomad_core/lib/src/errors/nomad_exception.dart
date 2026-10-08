/// Base exception class for all domain-level errors in Nomad.
abstract class NomadException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const NomadException(this.message, {this.code, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('NomadException: $message');
    if (code != null) buffer.write(' [Code: $code]');
    if (cause != null) buffer.write(' (Cause: $cause)');
    return buffer.toString();
  }
}

/// Thrown when an invalid state transition or operation occurs.
class DomainException extends NomadException {
  const DomainException(super.message, {super.code, super.cause});
}

/// Thrown when contract preconditions or invariants are violated.
class ContractViolationException extends NomadException {
  const ContractViolationException(super.message, {super.code, super.cause});
}
