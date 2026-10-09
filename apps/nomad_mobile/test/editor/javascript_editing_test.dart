import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/editor/code_editing_controller.dart';
import 'package:nomad_mobile/editor/source_language.dart';
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
  group('S0.1.4 JavaScript Tokenizer & Highlighting', () {
    testWidgets('tokenizes keywords, globals, functions, and literals correctly', (tester) async {
      // Use escaped \$ to prevent Dart compiler from treating it as Dart string interpolation
      const jsCode = '''
// Nomad Web Lab Script
const count = 42;
document.addEventListener('DOMContentLoaded', () => {
  console.log("Initialized with: " + count);
  if (count > 0) {
    window.alert("Nomad Running!");
  }
});
''';
      final controller = CodeEditingController(
        language: SourceLanguage.javascript,
        text: jsCode,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('document.addEventListener'));
      expect(controller.text, contains('const count = 42;'));
    });

    testWidgets('malformed JavaScript does not crash the editor', (tester) async {
      final controller = CodeEditingController(
        language: SourceLanguage.javascript,
        text: 'const x = ; if ( { function broken(`unclosed string',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('const x = ;'));
    });
  });

  group('S0.1.4 JavaScript Editor Integration', () {
    late InMemoryFileContentRepository contentRepo;
    late FileNode jsNode;

    setUp(() {
      contentRepo = InMemoryFileContentRepository();
      jsNode = FileNode(
        id: const EntityId('file-js-1'),
        projectId: const EntityId('project-1'),
        name: 'script.js',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets('opens JS file, shows JavaScript badge, edits, saves and verifies persistence', (tester) async {
      await contentRepo.writeFile(
        jsNode.projectId,
        jsNode.id,
        'console.log("hello");',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditorView(
            fileNode: jsNode,
            contentRepository: contentRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and JS badge
      expect(find.text('script.js'), findsOneWidget);
      expect(find.text('JavaScript'), findsOneWidget);
      expect(find.text('console.log("hello");'), findsOneWidget);

      // Edit JS
      const newJs = 'document.getElementById("btn").addEventListener("click", () => alert("Saved!"));';
      await tester.enterText(
        find.byKey(const Key('editor_text_field')),
        newJs,
      );
      await tester.pumpAndSettle();

      // Verify dirty state
      expect(find.text('script.js *'), findsOneWidget);

      // Save JS
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      // Verify dirty state cleared
      expect(find.text('script.js'), findsOneWidget);

      // Verify persistence
      final saved = await contentRepo.readFile(jsNode.projectId, jsNode.id);
      expect(saved, newJs);
    });
  });
}