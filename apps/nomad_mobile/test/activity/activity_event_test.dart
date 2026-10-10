import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/activity/activity_event.dart';

void main() {
  final fixedTime = DateTime(2025, 6, 15, 10, 30);

  group('ActivityEvent', () {
    test('stores all fields', () {
      final event = ActivityEvent(
        id: '1-0',
        timestamp: fixedTime,
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'Preview ready',
        details: 'index.html loaded',
        sourceUri: 'index.html',
        line: 12,
        column: 5,
        sessionId: 1,
      );

      expect(event.id, '1-0');
      expect(event.timestamp, fixedTime);
      expect(event.category, ActivityCategory.lifecycle);
      expect(event.severity, ActivitySeverity.info);
      expect(event.message, 'Preview ready');
      expect(event.details, 'index.html loaded');
      expect(event.sourceUri, 'index.html');
      expect(event.line, 12);
      expect(event.column, 5);
      expect(event.sessionId, 1);
    });

    test('optional fields default to null', () {
      final event = ActivityEvent(
        id: '1-1',
        timestamp: fixedTime,
        category: ActivityCategory.resource,
        severity: ActivitySeverity.warning,
        message: 'Missing asset',
        sessionId: 1,
      );

      expect(event.details, isNull);
      expect(event.sourceUri, isNull);
      expect(event.line, isNull);
      expect(event.column, isNull);
    });

    test('equality is based on id only', () {
      final a = ActivityEvent(
        id: 'same',
        timestamp: fixedTime,
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'A',
        sessionId: 1,
      );
      final b = ActivityEvent(
        id: 'same',
        timestamp: fixedTime,
        category: ActivityCategory.runtime,
        severity: ActivitySeverity.error,
        message: 'B',
        sessionId: 2,
      );
      final c = ActivityEvent(
        id: 'different',
        timestamp: fixedTime,
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'A',
        sessionId: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString includes key fields', () {
      final event = ActivityEvent(
        id: '1-0',
        timestamp: fixedTime,
        category: ActivityCategory.runtime,
        severity: ActivitySeverity.error,
        message: 'ReferenceError',
        sessionId: 1,
      );
      final s = event.toString();
      expect(s, contains('1-0'));
      expect(s, contains('runtime'));
      expect(s, contains('error'));
      expect(s, contains('ReferenceError'));
    });
  });

  group('ActivityCategory', () {
    test('has exactly three values', () {
      expect(ActivityCategory.values, hasLength(3));
      expect(
        ActivityCategory.values,
        containsAll([
          ActivityCategory.lifecycle,
          ActivityCategory.resource,
          ActivityCategory.runtime,
        ]),
      );
    });
  });

  group('ActivitySeverity', () {
    test('has exactly three values in order', () {
      expect(ActivitySeverity.values, [
        ActivitySeverity.info,
        ActivitySeverity.warning,
        ActivitySeverity.error,
      ]);
    });
  });
}
