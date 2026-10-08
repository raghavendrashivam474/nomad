/// A lightweight unique identifier wrapper for domain entities.
class EntityId {
  final String value;

  const EntityId(this.value)
      : assert(value.length > 0, 'EntityId cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
