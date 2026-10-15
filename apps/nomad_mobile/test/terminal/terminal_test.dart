import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_core/nomad_core.dart';
import 'package:nomad_mobile/terminal/command_dispatcher.dart';
import 'package:nomad_mobile/terminal/terminal_controller.dart';

// â”€â”€ Fakes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FakeWorkspaceRepo implements WorkspaceRepository {
  final List<FileNode> _nodes;
  bool createShouldFail = false;

  _FakeWorkspaceRepo([this._nodes = const []]);

  @override
  Future<List<FileNode>> getNodesForProject(EntityId projectId) async =>
      _nodes.where((n) => n.projectId == projectId).toList();
  @override
  Future<FileNode?> getNodeById(EntityId id) async {
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  Future<void> createNode(FileNode node) async {
    if (createShouldFail) {
      throw const DomainException('create failed');
    }
    _nodes.add(node);
  }

  @override
  Future<void> renameNode(EntityId id, String newName) async {}
  @override
  Future<void> moveNode(EntityId id, EntityId? newParentId) async {}
  @override
  Future<void> deleteNode(EntityId id) async {
    _nodes.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> deleteAllNodesForProject(EntityId projectId) async {}
}

class _FakeContentRepo implements FileContentRepository {
  final Map<String, List<int>> _files = {};
  bool writeShouldFail = false;

  void seed(EntityId fileId, List<int> bytes) {
    _files[fileId.value] = bytes;
  }

  @override
  Future<String> readFile(EntityId projectId, EntityId fileNodeId) async {
    final bytes = _files[fileNodeId.value];
    if (bytes == null) return '';
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<void> writeFile(
      EntityId projectId, EntityId fileNodeId, String content) async {
    if (writeShouldFail) {
      throw const DomainException('write failed');
    }
    _files[fileNodeId.value] = utf8.encode(content);
  }

  @override
  Future<List<int>> readFileBytes(
      EntityId projectId, EntityId fileNodeId) async {
    return _files[fileNodeId.value] ?? <int>[];
  }

  @override
  Future<void> writeFileBytes(
      EntityId projectId, EntityId fileNodeId, List<int> bytes) async {
    if (writeShouldFail) {
      throw const DomainException('write failed');
    }
    _files[fileNodeId.value] = bytes;
  }

  @override
  Future<void> deleteContent(
      EntityId projectId, EntityId fileNodeId) async {}
  @override
  Future<void> deleteAllContentForProject(EntityId projectId) async {}
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _projId = EntityId('proj-1');
final _now = DateTime(2025, 1, 1);

Project _makeProject([String name = 'TestProject']) => Project(
      id: _projId,
      name: name,
      type: ProjectType.web,
      createdAt: _now,
      updatedAt: _now,
    );

FileNode _folder(String id, String name, {EntityId? parentId}) => FileNode(
      id: EntityId(id),
      projectId: _projId,
      parentId: parentId,
      name: name,
      type: FileNodeType.folder,
      createdAt: _now,
      updatedAt: _now,
    );

FileNode _file(String id, String name, {EntityId? parentId}) => FileNode(
      id: EntityId(id),
      projectId: _projId,
      parentId: parentId,
      name: name,
      type: FileNodeType.file,
      createdAt: _now,
      updatedAt: _now,
    );

/// Workspace tree:
///   /
///   â”œâ”€â”€ src/          (folder, root)
///   â”‚   â”œâ”€â”€ main.dart (file)
///   â”‚   â””â”€â”€ utils/    (folder)
///   â”œâ”€â”€ README.md     (file, root)
///   â””â”€â”€ style.css     (file, root)
final _testNodes = [
  _folder('f-src', 'src'),
  _file('f-main', 'main.dart', parentId: const EntityId('f-src')),
  _folder('f-utils', 'utils', parentId: const EntityId('f-src')),
  _file('f-readme', 'README.md'),
  _file('f-style', 'style.css'),
];

TerminalController _makeController(
        [List<FileNode>? nodes, _FakeContentRepo? contentRepo]) =>
    TerminalController(
      workspaceRepository: _FakeWorkspaceRepo(nodes ?? _testNodes),
      contentRepository: contentRepo ?? _FakeContentRepo(),
    );

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Tests
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

void main() {
  // â”€â”€ Block 1: help, clear, pwd â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('help / clear / pwd', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('help lists all 9 commands', () async {
      await ctrl.executeCommand('help');
      final out = ctrl.outputLines.join('\n');
      for (final cmd in CommandDispatcher.supportedCommands) {
        expect(out, contains(cmd));
      }
    });

    test('clear empties output', () async {
      await ctrl.executeCommand('help');
      await ctrl.executeCommand('clear');
      expect(ctrl.outputLines, isEmpty);
    });

    test('pwd shows project path', () async {
      await ctrl.executeCommand('pwd');
      expect(ctrl.outputLines.any((l) => l.contains('/project/TestProject')),
          isTrue);
    });

    test('pwd without project', () async {
      final c = _makeController();
      await c.executeCommand('pwd');
      expect(c.outputLines.any((l) => l.contains('no active project')), isTrue);
      c.dispose();
    });

    test('empty input does nothing', () async {
      await ctrl.executeCommand('');
      expect(ctrl.outputLines, isEmpty);
    });

    test('unknown command shows error', () async {
      await ctrl.executeCommand('foobar');
      expect(ctrl.outputLines.any((l) => l.contains('Unknown command')), isTrue);
    });
  });

  // â”€â”€ Block 2: ls, cd â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('ls', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('root listing: folders first', () async {
      await ctrl.executeCommand('ls');
      final out = ctrl.outputLines.join('\n');
      expect(out.indexOf('src/'), lessThan(out.indexOf('README.md')));
    });

    test('subfolder listing', () async {
      await ctrl.executeCommand('cd src');
      await ctrl.executeCommand('ls');
      final out = ctrl.outputLines.join('\n');
      expect(out, contains('main.dart'));
      expect(out, contains('utils/'));
      expect(out, isNot(contains('README.md')));
    });

    test('empty directory', () async {
      final c = _makeController([]);
      c.setActiveProject(_makeProject());
      await c.executeCommand('ls');
      expect(c.outputLines.any((l) => l.contains('(empty)')), isTrue);
      c.dispose();
    });
  });

  group('cd', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('cd into folder', () async {
      await ctrl.executeCommand('cd src');
      expect(ctrl.cwdStack.length, 1);
      expect(ctrl.cwdDisplayPath, '/project/TestProject/src');
    });

    test('cd .. pops', () async {
      await ctrl.executeCommand('cd src');
      await ctrl.executeCommand('cd ..');
      expect(ctrl.cwdStack, isEmpty);
    });

    test('cd .. at root errors', () async {
      await ctrl.executeCommand('cd ..');
      expect(
          ctrl.outputLines.any((l) => l.contains('Already at project root')),
          isTrue);
    });

    test('cd (no args) resets', () async {
      await ctrl.executeCommand('cd src');
      await ctrl.executeCommand('cd');
      expect(ctrl.cwdStack, isEmpty);
    });

    test('cd into file errors', () async {
      await ctrl.executeCommand('cd README.md');
      expect(
          ctrl.outputLines.any((l) => l.contains('is a file')), isTrue);
    });

    test('cd nonexistent errors', () async {
      await ctrl.executeCommand('cd ghost');
      expect(
          ctrl.outputLines.any((l) => l.contains('No such directory')), isTrue);
    });

    test('cd with / rejected', () async {
      await ctrl.executeCommand('cd src/utils');
      expect(ctrl.outputLines.any((l) => l.contains('Invalid path')), isTrue);
    });
  });

  // â”€â”€ Block 4: tree â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('tree', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('tree shows full hierarchy', () async {
      await ctrl.executeCommand('tree');
      final out = ctrl.outputLines.join('\n');
      expect(out, contains('src/'));
      expect(out, contains('main.dart'));
      expect(out, contains('utils/'));
      expect(out, contains('README.md'));
      expect(out, contains('style.css'));
    });

    test('tree from subfolder', () async {
      await ctrl.executeCommand('cd src');
      await ctrl.executeCommand('tree');
      final out = ctrl.outputLines.join('\n');
      expect(out, contains('main.dart'));
      expect(out, contains('utils/'));
      // Root items should not appear in subtree
      expect(out, isNot(contains('style.css')));
    });

    test('tree respects depth limit', () async {
      // Build a 7-level deep tree: a/b/c/d/e/f/g
      final deepNodes = <FileNode>[];
      EntityId? parentId;
      for (final name in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        final id = EntityId('deep-$name');
        deepNodes.add(_folder(id.value, name, parentId: parentId));
        parentId = id;
      }
      final c = _makeController(deepNodes);
      c.setActiveProject(_makeProject());
      await c.executeCommand('tree');
      final out = c.outputLines.join('\n');
      // a through e should appear (depth 1-5)
      expect(out, contains('a/'));
      expect(out, contains('e/'));
      // f is at depth 6, should NOT appear
      expect(out, isNot(contains('f/')));
      expect(out, contains('output limited'));
      c.dispose();
    });

    test('tree with no project', () async {
      final c = _makeController();
      await c.executeCommand('tree');
      expect(c.outputLines.any((l) => l.contains('No active project')), isTrue);
      c.dispose();
    });

    test('tree with empty project', () async {
      final c = _makeController([]);
      c.setActiveProject(_makeProject());
      await c.executeCommand('tree');
      final out = c.outputLines.join('\n');
      expect(out, contains('/project/TestProject'));
      // No children
      expect(out, isNot(contains('---')));
      c.dispose();
    });
  });

  // â”€â”€ Block 4: mkdir â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('mkdir', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('mkdir creates folder', () async {
      await ctrl.executeCommand('mkdir assets');
      expect(ctrl.outputLines.any((l) => l.contains('Created folder: assets/')),
          isTrue);
    });

    test('mkdir missing name', () async {
      await ctrl.executeCommand('mkdir');
      expect(ctrl.outputLines.any((l) => l.contains('Usage:')), isTrue);
    });

    test('mkdir invalid name', () async {
      await ctrl.executeCommand('mkdir a/b');
      expect(ctrl.outputLines.any((l) => l.contains('Invalid')), isTrue);
    });

    test('mkdir collision', () async {
      await ctrl.executeCommand('mkdir src');
      expect(ctrl.outputLines.any((l) => l.contains('already exists')), isTrue);
    });

    test('mkdir no project', () async {
      final c = _makeController();
      await c.executeCommand('mkdir x');
      expect(c.outputLines.any((l) => l.contains('No active project')), isTrue);
      c.dispose();
    });
  });

  // â”€â”€ Block 4: touch â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('touch', () {
    late TerminalController ctrl;
    setUp(() {
      ctrl = _makeController();
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('touch creates file', () async {
      await ctrl.executeCommand('touch notes.txt');
      expect(
          ctrl.outputLines.any((l) => l.contains('Created file: notes.txt')),
          isTrue);
    });

    test('touch missing name', () async {
      await ctrl.executeCommand('touch');
      expect(ctrl.outputLines.any((l) => l.contains('Usage:')), isTrue);
    });

    test('touch collision', () async {
      await ctrl.executeCommand('touch README.md');
      expect(ctrl.outputLines.any((l) => l.contains('already exists')), isTrue);
    });

    test('touch partial failure rolls back', () async {
      final contentRepo = _FakeContentRepo()..writeShouldFail = true;
      final c = _makeController([], contentRepo);
      c.setActiveProject(_makeProject());
      await c.executeCommand('touch fail.txt');
      expect(
          c.outputLines.any((l) => l.contains('content init failed')), isTrue);
      c.dispose();
    });

    test('touch no project', () async {
      final c = _makeController();
      await c.executeCommand('touch x.txt');
      expect(c.outputLines.any((l) => l.contains('No active project')), isTrue);
      c.dispose();
    });
  });

  // â”€â”€ Block 4: cat â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('cat', () {
    late _FakeContentRepo contentRepo;
    late TerminalController ctrl;

    setUp(() {
      contentRepo = _FakeContentRepo();
      contentRepo.seed(
          const EntityId('f-readme'), utf8.encode('Hello World'));
      contentRepo.seed(const EntityId('f-main'), utf8.encode('void main() {}'));
      contentRepo.seed(const EntityId('f-style'), <int>[]);
      ctrl = _makeController(_testNodes, contentRepo);
      ctrl.setActiveProject(_makeProject());
    });
    tearDown(() => ctrl.dispose());

    test('cat displays text file', () async {
      await ctrl.executeCommand('cat README.md');
      expect(ctrl.outputLines.any((l) => l.contains('Hello World')), isTrue);
    });

    test('cat empty file', () async {
      await ctrl.executeCommand('cat style.css');
      expect(ctrl.outputLines.any((l) => l.contains('(empty file)')), isTrue);
    });

    test('cat missing file', () async {
      await ctrl.executeCommand('cat ghost.txt');
      expect(ctrl.outputLines.any((l) => l.contains('No such file')), isTrue);
    });

    test('cat folder errors', () async {
      await ctrl.executeCommand('cat src');
      expect(ctrl.outputLines.any((l) => l.contains('is a directory')), isTrue);
    });

    test('cat oversized file', () async {
      contentRepo.seed(
          const EntityId('f-readme'), List.filled(101 * 1024, 65));
      await ctrl.executeCommand('cat README.md');
      expect(ctrl.outputLines.any((l) => l.contains('too large')), isTrue);
    });

    test('cat binary file', () async {
      // PNG-like header with null bytes
      final binaryBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00];
      contentRepo.seed(const EntityId('f-readme'), binaryBytes);
      await ctrl.executeCommand('cat README.md');
      expect(ctrl.outputLines.any((l) => l.contains('Binary file')), isTrue);
    });

    test('cat binary with known extension shows MIME', () async {
      // Add a .png file
      final pngNode = _file('f-logo', 'logo.png');
      final nodes = [..._testNodes, pngNode];
      final cr = _FakeContentRepo();
      cr.seed(const EntityId('f-logo'), [0x89, 0x50, 0x00]);
      final c = _makeController(nodes, cr);
      c.setActiveProject(_makeProject());
      await c.executeCommand('cat logo.png');
      expect(c.outputLines.any((l) => l.contains('image/png')), isTrue);
      c.dispose();
    });

    test('cat no project', () async {
      final c = _makeController();
      await c.executeCommand('cat x');
      expect(c.outputLines.any((l) => l.contains('No active project')), isTrue);
      c.dispose();
    });
  });

  // â”€â”€ Output limits â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('output limits', () {
    test('line limit enforced', () {
      final ctrl = _makeController();
      for (int i = 0; i < 600; i++) {
        ctrl.appendOutput('line $i');
      }
      expect(ctrl.outputLines.length,
          lessThanOrEqualTo(TerminalController.maxLines));
      ctrl.dispose();
    });
  });
}