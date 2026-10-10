import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/activity/activity_controller.dart';
import 'package:nomad_mobile/activity/activity_event.dart';
import 'package:nomad_mobile/ui/activity/live_activity_panel.dart';

void main() {
  late ActivityController controller;

  setUp(() {
    controller = ActivityController(maxEvents: 50);
    controller.beginSession();
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildTestPanel({
    VoidCallback? onClose,
    void Function(String uri, int? line, int? col)? onNavigate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LiveActivityPanel(
          controller: controller,
          onClose: onClose,
          onNavigateToSource: onNavigate,
        ),
      ),
    );
  }

  group('LiveActivityPanel Widget Tests', () {
    testWidgets('renders calm empty state when no events exist',
        (tester) async {
      await tester.pumpWidget(buildTestPanel());

      expect(find.byKey(const Key('activity_empty_state')), findsOneWidget);
      expect(find.text('No activity recorded yet'), findsOneWidget);
      expect(find.byKey(const Key('activity_clear_button')), findsNothing);
    });

    testWidgets('renders events in reverse order (newest on top)',
        (tester) async {
      controller.add(controller.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'First: Loading started',
      ));
      controller.add(controller.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'Second: Ready',
      ));

      await tester.pumpWidget(buildTestPanel());

      expect(find.text('Second: Ready'), findsOneWidget);
      expect(find.text('First: Loading started'), findsOneWidget);

      // Verify header counter
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('expands and collapses diagnostic details on tap',
        (tester) async {
      final event = controller.createEvent(
        category: ActivityCategory.runtime,
        severity: ActivitySeverity.error,
        message: 'TypeError: Cannot read property of undefined',
        details: 'Stack trace: at line 42 in index.html',
        sourceUri: 'index.html',
        line: 42,
      );
      controller.add(event);

      await tester.pumpWidget(buildTestPanel());

      // Details should initially not be visible
      expect(find.text('Stack trace: at line 42 in index.html'), findsNothing);

      // Tap expand button
      final expandKey = Key('activity_expand_${event.id}');
      expect(find.byKey(expandKey), findsOneWidget);
      await tester.tap(find.byKey(expandKey));
      await tester.pumpAndSettle();

      // Details should now be visible
      expect(find.text('Stack trace: at line 42 in index.html'), findsOneWidget);
      expect(find.text('index.html:42'), findsOneWidget);

      // Tap collapse
      await tester.tap(find.byKey(expandKey));
      await tester.pumpAndSettle();

      expect(find.text('Stack trace: at line 42 in index.html'), findsNothing);
    });

    testWidgets('dismisses single event when close icon is tapped',
        (tester) async {
      final event1 = controller.createEvent(
        category: ActivityCategory.resource,
        severity: ActivitySeverity.warning,
        message: 'Asset 404: style.css',
      );
      final event2 = controller.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'Preview loaded',
      );
      controller.add(event1);
      controller.add(event2);

      await tester.pumpWidget(buildTestPanel());
      expect(controller.length, 2);

      // Tap dismiss on event1
      await tester.tap(find.byKey(Key('activity_dismiss_${event1.id}')));
      await tester.pumpAndSettle();

      expect(controller.length, 1);
      expect(find.text('Asset 404: style.css'), findsNothing);
      expect(find.text('Preview loaded'), findsOneWidget);
    });

    testWidgets('clears all events when clear button in header is tapped',
        (tester) async {
      controller.add(controller.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'Event 1',
      ));
      controller.add(controller.createEvent(
        category: ActivityCategory.lifecycle,
        severity: ActivitySeverity.info,
        message: 'Event 2',
      ));

      await tester.pumpWidget(buildTestPanel());
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('activity_clear_button')));
      await tester.pumpAndSettle();

      expect(controller.length, 0);
      expect(find.byKey(const Key('activity_empty_state')), findsOneWidget);
    });

    testWidgets('triggers source navigation callback with correct line and column',
        (tester) async {
      String? navUri;
      int? navLine;
      int? navCol;

      final event = controller.createEvent(
        category: ActivityCategory.runtime,
        severity: ActivitySeverity.error,
        message: 'SyntaxError',
        sourceUri: 'app.js',
        line: 15,
        column: 8,
      );
      controller.add(event);

      await tester.pumpWidget(buildTestPanel(
        onNavigate: (uri, line, col) {
          navUri = uri;
          navLine = line;
          navCol = col;
        },
      ));

      // Expand tile to reveal navigation button
      await tester.tap(find.byKey(Key('activity_expand_${event.id}')));
      await tester.pumpAndSettle();

      // Tap navigation button
      final navKey = Key('activity_navigate_${event.id}');
      expect(find.byKey(navKey), findsOneWidget);

      await tester.tap(find.byKey(navKey));
      await tester.pumpAndSettle();

      expect(navUri, 'app.js');
      expect(navLine, 15);
      expect(navCol, 8);
    });

    testWidgets('invokes onClose when panel close button is tapped',
        (tester) async {
      var closed = false;

      await tester.pumpWidget(buildTestPanel(
        onClose: () => closed = true,
      ));

      expect(find.byKey(const Key('activity_close_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('activity_close_button')));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}