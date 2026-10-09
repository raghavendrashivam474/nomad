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
  group('S0.1.2 Source Language Resolution', () {
    test('resolves file extensions correctly', () {
      expect(SourceLanguage.fromFileName('index.html'), SourceLanguage.html);
      expect(SourceLanguage.fromFileName('about.htm'), SourceLanguage.html);
      expect(SourceLanguage.fromFileName('style.css'), SourceLanguage.css);
      expect(
          SourceLanguage.fromFileName('script.js'), SourceLanguage.javascript);
      expect(SourceLanguage.fromFileName('app.mjs'), SourceLanguage.javascript);
      expect(
          SourceLanguage.fromFileName('module.cjs'), SourceLanguage.javascript);
      expect(
          SourceLanguage.fromFileName('README.md'), SourceLanguage.plainText);
      expect(
          SourceLanguage.fromFileName('notes.txt'), SourceLanguage.plainText);
      expect(
          SourceLanguage.fromFileName('noextension'), SourceLanguage.plainText);
    });
  });

  group('S0.1.2 HTML Highlighting Controller', () {
    testWidgets('tokenizes valid HTML without error', (tester) async {
      final controller = CodeEditingController(
        language: SourceLanguage.html,
        text:
            '<!DOCTYPE html>\n<html>\n<!-- Comment -->\n<body class="main">&copy; Hello</body>\n</html>',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('<!DOCTYPE html>'));
      expect(controller.text, contains('<!-- Comment -->'));
    });

    testWidgets('malformed HTML does not crash the editor', (tester) async {
      final controller = CodeEditingController(
        language: SourceLanguage.html,
        text: '<div class="broken <p> unfinished </html> <!-- unclosed comment',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller),
          ),
        ),
      );

      expect(controller.text, contains('<div class="broken'));
    });
  });

  group('S0.1.2 HTML Editor Integration', () {
    late InMemoryFileContentRepository contentRepo;
    late FileNode htmlNode;

    setUp(() {
      contentRepo = InMemoryFileContentRepository();
      htmlNode = FileNode(
        id: const EntityId('file-html-1'),
        projectId: const EntityId('project-1'),
        name: 'index.html',
        type: FileNodeType.file,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets('opens HTML file, shows language badge, edits and saves',
        (tester) async {
      await contentRepo.writeFile(
        htmlNode.projectId,
        htmlNode.id,
        '<h1>Initial HTML</h1>',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditorView(
            fileNode: htmlNode,
            contentRepository: contentRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and HTML badge
      expect(find.text('index.html'), findsOneWidget);
      expect(find.text('HTML'), findsOneWidget);
      expect(find.text('<h1>Initial HTML</h1>'), findsOneWidget);

      // Edit HTML
      await tester.enterText(
        find.byKey(const Key('editor_text_field')),
        '<h1>Updated Nomad HTML</h1>\n<p>Authoring works!</p>',
      );
      await tester.pumpAndSettle();

      // Verify dirty state
      expect(find.text('index.html *'), findsOneWidget);

      // Save HTML
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      // Verify dirty cleared
      expect(find.text('index.html'), findsOneWidget);

      // Verify persistence
      final savedContent =
          await contentRepo.readFile(htmlNode.projectId, htmlNode.id);
      expect(
          savedContent, '<h1>Updated Nomad HTML</h1>\n<p>Authoring works!</p>');
    });
  });
}
