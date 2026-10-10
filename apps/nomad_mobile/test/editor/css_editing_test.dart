import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/editor/code_editing_controller.dart';
import 'package:nomad_mobile/editor/source_language.dart';
import 'package:nomad_mobile/ui/editor_view.dart';

class InMemoryFileContentRepository implements FileContentRepository {
  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    final text = await readFile(projectId, fileNodeId);
    return utf8.encode(text);
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    await writeFile(projectId, fileNodeId, utf8.decode(bytes));
  }

  final Map<String, String> _contents = {};

  String _key(EntityId projectId, EntityId fileNodeId) =>
      '${projectId.value}:${fileNodeId.value}';

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    return _contents[_key(projectId, fileNodeId)] ?? '';
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    _contents[_key(projectId, fileNodeId)] = content;
  }

  @override
  Future<void> deleteContent(EntityId projectId, EntityId fileNodeId) async {
    _contents.remove(_key(projectId, fileNodeId));
  }

  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {
    _contents.removeWhere((k, _) => k.startsWith('${projectId.value}:'));
  }
}

void main() {
  group('S0.1.3 CSS Tokenizer & Highlighting', () {
    testWidgets(
        'tokenizes valid CSS properties, selectors and values without error',
        (tester) async {
      const cssCode = '''
/* Nomad Theme Stylesheet */
@media (min-width: 600px) {
  body {
    background-color: #0f172a;
    font-size: 16px;
    padding: 1.5rem;
  }
}
.container {
  max-width: 480px;
}
#action-btn:hover {
  color: #38bdf8;
}
''';
      final controller = CodeEditingController(
        language: SourceLanguage.css,
        text: cssCode,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('background-color'));
      expect(controller.text, contains('#38bdf8'));
      expect(controller.text, contains('/* Nomad Theme Stylesheet */'));
    });

    testWidgets('malformed CSS does not crash the editor', (tester) async {
      final controller = CodeEditingController(
        language: SourceLanguage.css,
        text: 'body { background: #; font-size: @broken /* unclosed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('body { background: #;'));
    });
  });

  group('S0.1.3 CSS Editor Integration', () {
    late InMemoryFileContentRepository contentRepo;
    late FileNode cssNode;

    setUp(() {
      contentRepo = InMemoryFileContentRepository();
      cssNode = FileNode(
        id: const EntityId('file-css-1'),
        projectId: const EntityId('project-1'),
        name: 'style.css',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets(
        'opens CSS file, shows CSS badge, edits, saves and verifies persistence',
        (tester) async {
      await contentRepo.writeFile(
        cssNode.projectId,
        cssNode.id,
        'body { margin: 0; }',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditorView(
            fileNode: cssNode,
            contentRepository: contentRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and CSS badge
      expect(find.text('style.css'), findsOneWidget);
      expect(find.text('CSS'), findsOneWidget);
      expect(find.text('body { margin: 0; }'), findsOneWidget);

      // Edit CSS
      const newCss =
          'body {\n  margin: 0;\n  background-color: #0f172a;\n  color: #f8fafc;\n}';
      await tester.enterText(
        find.byKey(const Key('editor_text_field')),
        newCss,
      );
      await tester.pumpAndSettle();

      // Verify dirty state
      expect(find.text('style.css *'), findsOneWidget);

      // Save CSS
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      // Verify dirty state cleared
      expect(find.text('style.css'), findsOneWidget);

      // Verify persistence
      final saved = await contentRepo.readFile(cssNode.projectId, cssNode.id);
      expect(saved, newCss);
    });
  });
}
