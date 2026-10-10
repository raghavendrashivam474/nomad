import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/ui/editor_view.dart';

// â”€â”€ In-memory stubs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class InMemoryContentRepository implements FileContentRepository {
  final Map<String, String> _store = {};
  final Map<String, List<int>> _binaryStore = {};

  String _key(EntityId projectId, EntityId fileId) =>
      '${projectId.value}::${fileId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileId) async {
    return _store[_key(projectId, fileId)] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileId, String content) async {
    _store[_key(projectId, fileId)] = content;
  }

  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    return _binaryStore[_key(projectId, fileNodeId)] ?? [];
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    _binaryStore[_key(projectId, fileNodeId)] = bytes;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    _store.remove(_key(projectId, fileNodeId));
    _binaryStore.remove(_key(projectId, fileNodeId));
  }

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {
    _store.removeWhere((k, _) => k.startsWith('${projectId.value}::'));
    _binaryStore.removeWhere((k, _) => k.startsWith('${projectId.value}::'));
  }
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

FileNode _makeFileNode({String name = 'index.html'}) {
  return FileNode(
    id: const EntityId('file-1'),
    projectId: const EntityId('project-1'),
    name: name,
    type: FileNodeType.file,
    createdAt: DateTime.utc(2025, 1, 1),
    updatedAt: DateTime.utc(2025, 1, 1),
  );
}

Widget _buildEditor({
  required FileContentRepository contentRepo,
  FileNode? fileNode,
}) {
  return MaterialApp(
    home: EditorView(
      fileNode: fileNode ?? _makeFileNode(),
      contentRepository: contentRepo,
    ),
  );
}

/// Simulates the on-screen keyboard by setting a bottom view inset.
void _simulateKeyboard(WidgetTester tester, double keyboardHeight) {
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
}

// â”€â”€ Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorView overflow regression (WX-1)', () {
    late InMemoryContentRepository contentRepo;

    setUp(() {
      contentRepo = InMemoryContentRepository();
    });

    // â”€â”€ Phone portrait, keyboard closed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Phone portrait (390x844) â€” keyboard closed â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Phone portrait, keyboard closed should not overflow');
      },
    );

    // â”€â”€ Phone portrait, keyboard open â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Phone portrait (390x844) â€” keyboard open (300px) â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        _simulateKeyboard(tester, 300);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Phone portrait with keyboard should not overflow');
      },
    );

    // â”€â”€ Phone landscape, keyboard closed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Phone landscape (844x390) â€” keyboard closed â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Phone landscape, keyboard closed should not overflow');
      },
    );

    // â”€â”€ Phone landscape, keyboard open (tightest scenario) â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Phone landscape (844x390) â€” keyboard open (250px) â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1.0;
        _simulateKeyboard(tester, 250);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason:
                'Phone landscape with keyboard is the tightest layout and must not overflow');
      },
    );

    // â”€â”€ Tablet portrait, keyboard open â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Tablet portrait (800x1280) â€” keyboard open (350px) â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1280);
        tester.view.devicePixelRatio = 1.0;
        _simulateKeyboard(tester, 350);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Tablet portrait with keyboard should not overflow');
      },
    );

    // â”€â”€ Tablet landscape, keyboard open (37px overflow scenario) â”€
    testWidgets(
      'Tablet landscape (1280x800) â€” keyboard open (400px) â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        _simulateKeyboard(tester, 400);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason:
                'Tablet landscape with keyboard should not overflow (historical 37px defect)');
      },
    );

    // â”€â”€ Panel expanded on constrained viewport â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Panel expanded on phone landscape with keyboard â€” no overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1.0;
        _simulateKeyboard(tester, 250);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        // Open the contextual code panel
        final toggleFinder = find.byKey(const Key('accessory_panel_toggle'));
        if (toggleFinder.evaluate().isNotEmpty) {
          await tester.tap(toggleFinder);
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull,
            reason:
                'Expanded panel + keyboard on phone landscape must not overflow');
      },
    );

    // â”€â”€ Keyboard close restores layout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    testWidgets(
      'Keyboard open then close restores full layout',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_buildEditor(contentRepo: contentRepo));
        await tester.pumpAndSettle();

        // Open keyboard
        _simulateKeyboard(tester, 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Close keyboard
        _simulateKeyboard(tester, 0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Layout must recover after keyboard dismissal');

        // Verify text field is still present and usable
        expect(find.byKey(const Key('editor_text_field')), findsOneWidget);
      },
    );
  });
}
