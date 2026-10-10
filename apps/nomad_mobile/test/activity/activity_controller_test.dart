import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/activity/activity_controller.dart';
import 'package:nomad_mobile/activity/activity_event.dart';

void main() {
  late ActivityController sut;
  var _idCounter = 0;

  setUp(() {
    sut = ActivityController(maxEvents: 5);
    _idCounter = 0;
  });

  tearDown(() {
    sut.dispose();
  });

  // ── Helpers ────────────────────────────────────────────────

  ActivityEvent _makeEvent({
    String? message,
    ActivityCategory category = ActivityCategory.lifecycle,
    ActivitySeverity severity = ActivitySeverity.info,
    int? sessionId,
  }) {
    _idCounter++;
    return ActivityEvent(
      id: 'test-$_idCounter',
      timestamp: DateTime.now(),
      category: category,
      severity: severity,
      message: message ?? 'test-$_idCounter',
      sessionId: sessionId ?? sut.currentSessionId,
    );
  }

  // ── Session lifecycle ──────────────────────────────────────

  group('session', () {
    test('initial sessionId is 0', () {
      expect(sut.currentSessionId, 0);
    });

    test('beginSession increments id', () {
      expect(sut.beginSession(), 1);
      expect(sut.beginSession(), 2);
      expect(sut.currentSessionId, 2);
    });

    test('beginSession does not clear events', () {
      sut.beginSession();
      sut.add(_makeEvent());
      expect(sut.length, 1);

      sut.beginSession();
      expect(sut.length, 1);
    });
  });

  // ── Add ────────────────────────────────────────────────────

  group('add', () {
    test('adds event and notifies', () {
      sut.beginSession();
      var notified = 0;
      sut.addListener(() => notified++);

      sut.add(_makeEvent(message: 'hello'));

      expect(sut.length, 1);
      expect(sut.events.first.message, 'hello');
      expect(notified, 1);
    });

    test('rejects stale session events silently', () {
      sut.beginSession(); // session 1
      sut.add(_makeEvent());
      expect(sut.length, 1);

      sut.beginSession(); // session 2
      sut.add(_makeEvent(sessionId: 1));
      expect(sut.length, 1);
    });

    test('evicts oldest when exceeding maxEvents', () {
      sut.beginSession();
      for (var i = 0; i < 7; i++) {
        sut.add(_makeEvent(message: 'msg-$i'));
      }

      expect(sut.length, 5);
      expect(sut.events.map((e) => e.message).toList(), [
        'msg-2',
        'msg-3',
        'msg-4',
        'msg-5',
        'msg-6',
      ]);
    });

    test('preserves newest events on eviction', () {
      sut.beginSession();
      for (var i = 0; i < 10; i++) {
        sut.add(_makeEvent(
          message: 'ev-$i',
          severity: i == 9 ? ActivitySeverity.error : ActivitySeverity.info,
        ));
      }

      expect(sut.length, 5);
      expect(sut.events.last.message, 'ev-9');
      expect(sut.events.last.severity, ActivitySeverity.error);
    });
  });

  // ── createEvent ────────────────────────────────────────────

  group('createEvent', () {
    test('stamps id, timestamp, and sessionId automatically', () {
      sut.beginSession();
      final e = sut.createEvent(
        category: ActivityCategory.resource,
        severity: ActivitySeverity.warning,
        message: '404',
      );

      expect(e.id, startsWith('1-'));
      expect(e.sessionId, 1);
      expect(e.timestamp, isA<DateTime>());
      expect(e.category, ActivityCategory.resource);
      expect(e.message, '404');
    });

    test('ids are unique within a session', () {
      sut.beginSession();
      final a = sut.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'a',
      );
      final b = sut.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'b',
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('id counter resets on new session', () {
      sut.beginSession(); // 1
      final a = sut.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'a',
      );
      sut.beginSession(); // 2
      final b = sut.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'b',
      );

      expect(a.id, '1-0');
      expect(b.id, '2-0');
    });
  });

  // ── Dismiss ────────────────────────────────────────────────

  group('dismiss', () {
    test('removes event by id and notifies', () {
      sut.beginSession();
      final e = _makeEvent(message: 'doomed');
      sut.add(e);
      expect(sut.length, 1);

      var notified = 0;
      sut.addListener(() => notified++);
      sut.dismiss(e.id);

      expect(sut.length, 0);
      expect(notified, 1);
    });

    test('does not notify when id not found', () {
      sut.beginSession();
      var notified = 0;
      sut.addListener(() => notified++);

      sut.dismiss('nonexistent');
      expect(notified, 0);
    });

    test('only removes the targeted event', () {
      sut.beginSession();
      final a = _makeEvent(message: 'keep');
      final b = _makeEvent(message: 'remove');
      final c = _makeEvent(message: 'keep-too');
      sut.add(a);
      sut.add(b);
      sut.add(c);

      sut.dismiss(b.id);
      expect(sut.length, 2);
      expect(sut.events.map((e) => e.message), ['keep', 'keep-too']);
    });
  });

  // ── Clear ──────────────────────────────────────────────────

  group('clear', () {
    test('removes all events and notifies', () {
      sut.beginSession();
      sut.add(_makeEvent());
      sut.add(_makeEvent());
      expect(sut.length, 2);

      var notified = 0;
      sut.addListener(() => notified++);
      sut.clear();

      expect(sut.length, 0);
      expect(notified, 1);
    });

    test('does not notify when already empty', () {
      var notified = 0;
      sut.addListener(() => notified++);
      sut.clear();
      expect(notified, 0);
    });

    test('does not reset session', () {
      sut.beginSession();
      sut.add(_makeEvent());
      sut.clear();
      expect(sut.currentSessionId, 1);
    });
  });

  // ── Dispose ────────────────────────────────────────────────

  group('dispose', () {
    test('can be disposed without error', () {
      sut.beginSession();
      sut.add(_makeEvent());
      // tearDown will call dispose — just verify no throw up to here
      expect(sut.length, 1);
    });
  });

  // ── Default max ────────────────────────────────────────────

  group('defaults', () {
    test('defaultMaxEvents is 200', () {
      expect(ActivityController.defaultMaxEvents, 200);
    });

    test('default constructor uses defaultMaxEvents', () {
      final c = ActivityController();
      expect(c.maxEvents, 200);
      c.dispose();
    });
  });
}
