import 'package:test/test.dart';
import 'package:nomad_core/nomad_core.dart';

void main() {
  group('EntityId', () {
    test('equals identical value', () {
      const id1 = EntityId('project-123');
      const id2 = EntityId('project-123');
      const id3 = EntityId('project-456');

      expect(id1, equals(id2));
      expect(id1 == id3, isFalse);
      expect(id1.toString(), equals('project-123'));
    });

    test('throws assertion if empty value provided', () {
      expect(() => EntityId(''), throwsA(isA<AssertionError>()));
    });
  });

  group('NomadException', () {
    test('formats message correctly', () {
      const ex = DomainException('Entity not found', code: 'NOT_FOUND');
      expect(ex.toString(), contains('Entity not found'));
      expect(ex.toString(), contains('NOT_FOUND'));
    });

    test('ContractViolationException formats correctly', () {
      const ex = ContractViolationException('Incompatible contract');
      expect(ex.message, equals('Incompatible contract'));
    });
  });
}
