import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mobile/app/nomad_app.dart';

void main() {
  testWidgets('App renders Phone layout on narrow screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const NomadApp());
    await tester.pumpAndSettle();

    expect(find.text('Nomad'), findsWidgets);
    expect(find.text('Development. Everywhere You Go.'), findsOneWidget);
    expect(find.text('Phone View'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('App renders Tablet layout on wide screens',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const NomadApp());
    await tester.pumpAndSettle();

    expect(find.text('Tablet View'), findsOneWidget);
    expect(find.text('Nomad — Mobile-First Development Lab'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });
}
