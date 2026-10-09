import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/editor/code_accessory_bar.dart';
import 'package:nomad_mobile/editor/contextual_code_panel.dart';
import 'package:nomad_mobile/ui/editor_view.dart';

class InMemoryFileContentRepository implements FileContentRepository {
  final Map<String, String> _contents = {};

  String _key(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}:${fileNodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return _contents[_key(projectId, fileNodeId)] ?? '';
  }

  @override
  Future<void> writeFile(
    EntityId projectId,
    EntityId fileNodeId,
    String content,
  ) async {
    _contents[_key(projectId, fileNodeId)] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    _contents.remove(_key(projectId, fileNodeId));
  }

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {
    _contents.removeWhere((k, v) => k.startsWith('${projectId.value}:'));
  }
}

void main() {
  late InMemoryFileContentRepository repo;
  const projectId = EntityId('test_proj');
  const htmlNodeId = EntityId('test_html');
  const jsNodeId = EntityId('test_js');

  final testNodeHtml = FileNode(
    id: htmlNodeId,
    projectId: projectId,
    name: 'index.html',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testNodeJs = FileNode(
    id: jsNodeId,
    projectId: projectId,
    name: 'app.js',
    type: FileNodeType.file,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    repo = InMemoryFileContentRepository();
    repo.writeFile(projectId, htmlNodeId, '<h1>Hello</h1>');
    repo.writeFile(projectId, jsNodeId, 'let x = 10;');
  });

  Widget buildTestWidget({required FileNode node}) {
    return MaterialApp(
      home: EditorView(
        fileNode: node,
        contentRepository: repo,
      ),
    );
  }

  testWidgets('CodeAccessoryBar renders and panel toggle works',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(node: testNodeHtml));
    await tester.pumpAndSettle();

    // Verify accessory bar exists
    expect(find.byType(CodeAccessoryBar), findsOneWidget);
    expect(find.byType(ContextualCodePanel), findsNothing);

    // Toggle panel on
    await tester.tap(find.byKey(const Key('accessory_panel_toggle')));
    await tester.pumpAndSettle();

    // Verify panel is now open
    expect(find.byType(ContextualCodePanel), findsOneWidget);
    expect(find.text('HTML Tools'), findsOneWidget);

    // Close panel with panel close button
    await tester.tap(find.byKey(const Key('contextual_panel_close')));
    await tester.pumpAndSettle();

    expect(find.byType(ContextualCodePanel), findsNothing);
  });

  testWidgets('Tapping accessory symbol inserts text and sets dirty state',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(node: testNodeHtml));
    await tester.pumpAndSettle();

    // Tap ';' in accessory bar
    final semicolonFinder = find.widgetWithText(Material, ';').first;
    await tester.tap(semicolonFinder);
    await tester.pumpAndSettle();

    // Verify save button is enabled (dirty state)
    final saveButton = tester
        .widget<FilledButton>(find.byKey(const Key('editor_save_button')));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('ContextualCodePanel presents correct language snippets for JS',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(node: testNodeJs));
    await tester.pumpAndSettle();

    // Open panel
    await tester.tap(find.byKey(const Key('accessory_panel_toggle')));
    await tester.pumpAndSettle();

    expect(find.text('JavaScript Tools'), findsOneWidget);
    expect(find.text('function()'), findsOneWidget);
    expect(find.text('console.log()'), findsOneWidget);
  });
}
