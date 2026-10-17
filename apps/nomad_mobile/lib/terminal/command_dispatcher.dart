import 'dart:convert';

import 'package:nomad_core/nomad_core.dart';

/// Navigation side-effect requested by a command.
enum NavigationAction { none, pushFolder, popFolder, resetToRoot }

/// Outcome of a single terminal command execution.
class CommandResult {
  final String output;
  final bool isError;
  final bool shouldClear;
  final NavigationAction navigation;
  final EntityId? targetFolderId;
  final String? targetFolderName;

  const CommandResult({
    this.output = '',
    this.isError = false,
    this.shouldClear = false,
    this.navigation = NavigationAction.none,
    this.targetFolderId,
    this.targetFolderName,
  });
}

/// Read-only snapshot of terminal state passed to commands.
class CommandContext {
  final Project? activeProject;
  final String cwdDisplayPath;
  final EntityId? currentFolderId;
  final List<PathSegment> cwdStack;
  final WorkspaceRepository? workspaceRepository;
  final FileContentRepository? contentRepository;

  const CommandContext({
    this.activeProject,
    required this.cwdDisplayPath,
    this.currentFolderId,
    this.cwdStack = const [],
    this.workspaceRepository,
    this.contentRepository,
  });
}

/// A named folder in the CWD navigation stack.
class PathSegment {
  final EntityId id;
  final String name;
  const PathSegment(this.id, this.name);
}

/// Tokenizes V1 input and dispatches to built-in command handlers.
///
/// V1 syntax: `command [arg1] [arg2]`
/// No pipes, redirection, chaining, globbing, quoting, or env vars.
class CommandDispatcher {
  static const List<String> supportedCommands = [
    'help',
    'clear',
    'pwd',
    'ls',
    'cd',
    'tree',
    'mkdir',
    'touch',
    'cat',
    'rm',
    'rmdir',
  ];

  /// Maximum tree traversal depth from the starting directory.
  static const int maxTreeDepth = 5;

  /// Maximum nodes visited during tree traversal.
  static const int maxTreeNodes = 500;

  /// Maximum file size readable by cat (100 KB).
  static const int maxCatBytes = 100 * 1024;

  /// Number of leading bytes checked for binary detection.
  static const int binaryCheckLength = 512;

  Future<CommandResult> dispatch(String input, CommandContext context) async {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) return const CommandResult();

    final name = tokens.first.toLowerCase();
    final args = tokens.sublist(1);

    switch (name) {
      case 'help':
        return _help();
      case 'clear':
        return const CommandResult(shouldClear: true);
      case 'pwd':
        return _pwd(context);
      case 'ls':
        return await _ls(args, context);
      case 'cd':
        return await _cd(args, context);
      case 'tree':
        return await _tree(args, context);
      case 'mkdir':
        return await _mkdir(args, context);
      case 'touch':
        return await _touch(args, context);
      case 'cat':
        return await _cat(args, context);
      case 'rm':
        return await _rm(args, context);
      case 'rmdir':
        return await _rmdir(args, context);
      default:
        return CommandResult(
          output:
              'Unknown command: "$name". Type "help" for available commands.',
          isError: true,
        );
    }
  }

    List<String> _tokenize(String input) {
    final trimmed = input.trim();
    if (trimmed.toLowerCase() == 'cd..') {
      return ['cd', '..'];
    }
    if (trimmed.toLowerCase().startsWith('cd..')) {
      final rest = trimmed.substring(4).trim();
      return ['cd', '..', if (rest.isNotEmpty) rest];
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ help Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  CommandResult _help() {
    const lines = [
      'Nomad Terminal v1 Ã¢â‚¬â€ Supported Commands',
      '',
      '  help            Show this help message',
      '  clear           Clear the terminal output',
      '  pwd             Print the current working directory',
      '  ls              List directory contents',
      '  cd <dir>        Change directory (.. = up, empty = root)',
      '  tree            Show project file tree',
      '  mkdir <name>    Create a new folder',
      '  touch <name>    Create a new empty file',
      '  cat <file>      Display file contents',
      '  rm <file>       Remove a file',
      '  rmdir <dir>     Remove an empty directory',
      '',
      'V1 Limitations:',
      '  No pipes, redirection, chaining, globbing, quoting,',
      '  environment variables, or host filesystem access.',
      '  Filenames with spaces are not supported.',
    ];
    return CommandResult(output: lines.join('\n'));
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ pwd Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  CommandResult _pwd(CommandContext context) {
    if (context.activeProject == null) {
      return const CommandResult(output: '/ (no active project)');
    }
    return CommandResult(output: context.cwdDisplayPath);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ ls Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _ls(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (context.workspaceRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);

      final children = nodes
          .where((n) => n.parentId == context.currentFolderId)
          .toList();

      children.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (children.isEmpty) {
        return const CommandResult(output: '(empty)');
      }

      final lines = children.map((n) {
        final suffix = n.isFolder ? '/' : '';
        return '${n.name}$suffix';
      }).toList();

      return CommandResult(output: lines.join('\n'));
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ cd Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _cd(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }

    if (args.isEmpty) {
      return const CommandResult(
        output: 'Returned to project root.',
        navigation: NavigationAction.resetToRoot,
      );
    }

    final target = args.first;

    if (target == '..') {
      if (context.cwdStack.isEmpty) {
        return const CommandResult(
            output: 'Already at project root.', isError: true);
      }
      return const CommandResult(
        output: '..',
        navigation: NavigationAction.popFolder,
      );
    }

    if (target == '.' ||
        target.contains('/') ||
        target.contains('\\') ||
        target.contains('..')) {
      return CommandResult(
        output:
            'Invalid path: "$target". V1 supports single folder names and ".." only.',
        isError: true,
      );
    }

    if (context.workspaceRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);

      final matches = nodes
          .where((n) =>
              n.name == target && n.parentId == context.currentFolderId)
          .toList();

      if (matches.isEmpty) {
        return CommandResult(
            output: 'No such directory: "$target"', isError: true);
      }

      final node = matches.first;
      if (!node.isFolder) {
        return CommandResult(
            output: '"$target" is a file, not a directory.',
            isError: true);
      }

      return CommandResult(
        output: '${node.name}/',
        navigation: NavigationAction.pushFolder,
        targetFolderId: node.id,
        targetFolderName: node.name,
      );
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ tree Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _tree(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (context.workspaceRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);

      // Build parent Ã¢â€ â€™ children map
      final childrenMap = <EntityId?, List<FileNode>>{};
      for (final node in nodes) {
        childrenMap.putIfAbsent(node.parentId, () => []).add(node);
      }

      // Sort: folders first, then alphabetical
      for (final list in childrenMap.values) {
        list.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      }

      final lines = <String>[];
      final rootLabel = context.cwdDisplayPath;
      lines.add(rootLabel);

      int visitedCount = 1;
      bool truncated = false;

      void walk(EntityId? parentId, String prefix, int depth) {
        if (truncated) return;
        if (depth > maxTreeDepth) {
          if (childrenMap[parentId]?.isNotEmpty == true) {
            truncated = true;
          }
          return;
        }

        final children = childrenMap[parentId];
        if (children == null || children.isEmpty) return;

        for (int i = 0; i < children.length; i++) {
          if (visitedCount >= maxTreeNodes) {
            truncated = true;
            return;
          }

          final child = children[i];
          visitedCount++;
          final isLast = i == children.length - 1;
          final connector = isLast ? '\u2514\u2500\u2500 ' : '\u251c\u2500\u2500 ';
          final suffix = child.isFolder ? '/' : '';
          lines.add('$prefix$connector${child.name}$suffix');

          if (child.isFolder) {
            final childPrefix =
                prefix + (isLast ? '    ' : '\u2502   ');
            walk(child.id, childPrefix, depth + 1);
          }
        }
      }

      walk(context.currentFolderId, '', 1);

      if (truncated) {
        lines.add(
            '... (output limited: max $maxTreeNodes nodes or $maxTreeDepth levels)');
      }

      return CommandResult(output: lines.join('\n'));
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ mkdir Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _mkdir(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (args.isEmpty) {
      return const CommandResult(
          output: 'Usage: mkdir <name>', isError: true);
    }

    final name = args.first;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      return CommandResult(
          output: 'Invalid folder name: "$name"', isError: true);
    }

    if (context.workspaceRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);
      final collision = nodes.any(
          (n) => n.name == name && n.parentId == context.currentFolderId);
      if (collision) {
        return CommandResult(
            output: '"$name" already exists.', isError: true);
      }

      final now = DateTime.now();
      final node = FileNode(
        id: EntityId('term-${now.microsecondsSinceEpoch}'),
        projectId: context.activeProject!.id,
        parentId: context.currentFolderId,
        name: name,
        type: FileNodeType.folder,
        createdAt: now,
        updatedAt: now,
      );

      await context.workspaceRepository!.createNode(node);
      return CommandResult(output: 'Created folder: $name/');
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ touch Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _touch(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (args.isEmpty) {
      return const CommandResult(
          output: 'Usage: touch <name>', isError: true);
    }

    final name = args.first;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      return CommandResult(
          output: 'Invalid file name: "$name"', isError: true);
    }

    if (context.workspaceRepository == null ||
        context.contentRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);
      final collision = nodes.any(
          (n) => n.name == name && n.parentId == context.currentFolderId);
      if (collision) {
        return CommandResult(
            output: '"$name" already exists.', isError: true);
      }

      final now = DateTime.now();
      final node = FileNode(
        id: EntityId('term-${now.microsecondsSinceEpoch}'),
        projectId: context.activeProject!.id,
        parentId: context.currentFolderId,
        name: name,
        type: FileNodeType.file,
        createdAt: now,
        updatedAt: now,
      );

      await context.workspaceRepository!.createNode(node);

      // Initialize empty content
      try {
        await context.contentRepository!
            .writeFile(context.activeProject!.id, node.id, '');
      } catch (contentError) {
        // Partial failure: node created but content init failed.
        // Attempt rollback.
        try {
          await context.workspaceRepository!.deleteNode(node.id);
        } catch (_) {
          // Rollback failed Ã¢â‚¬â€ report both errors.
        }
        return CommandResult(
          output:
              'Error: file node created but content init failed. Rolled back. ($contentError)',
          isError: true,
        );
      }

      return CommandResult(output: 'Created file: $name');
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ cat Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<CommandResult> _cat(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (args.isEmpty) {
      return const CommandResult(
          output: 'Usage: cat <file>', isError: true);
    }

    final name = args.first;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      return CommandResult(
          output: 'Invalid file name: "$name"', isError: true);
    }

    if (context.workspaceRepository == null ||
        context.contentRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);
      final matches = nodes
          .where(
              (n) => n.name == name && n.parentId == context.currentFolderId)
          .toList();

      if (matches.isEmpty) {
        return CommandResult(
            output: 'No such file: "$name"', isError: true);
      }

      final node = matches.first;
      if (node.isFolder) {
        return CommandResult(
            output: '"$name" is a directory.', isError: true);
      }

      final bytes = await context.contentRepository!
          .readFileBytes(context.activeProject!.id, node.id);

      if (bytes.isEmpty) {
        return const CommandResult(output: '(empty file)');
      }

      // Size check
      if (bytes.length > maxCatBytes) {
        return CommandResult(
          output:
              'File too large to display (${bytes.length} bytes, max $maxCatBytes).',
          isError: true,
        );
      }

      // Binary detection: null byte in first 512 bytes
      final checkLen =
          bytes.length < binaryCheckLength ? bytes.length : binaryCheckLength;
      for (int i = 0; i < checkLen; i++) {
        if (bytes[i] == 0) {
          final ext =
              name.contains('.') ? name.split('.').last.toLowerCase() : '';
          final mime = _guessMime(ext);
          return CommandResult(
            output:
                'Binary file not displayed ($mime, ${bytes.length} bytes).',
            isError: true,
          );
        }
      }

      // Decode as UTF-8
      final text = utf8.decode(bytes, allowMalformed: true);
      return CommandResult(output: text);
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }


  // ── rm ────────────────────────────────────────────────────────────────

  Future<CommandResult> _rm(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (args.isEmpty) {
      return const CommandResult(
          output: 'Usage: rm <file>', isError: true);
    }

    final name = args.first;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      return CommandResult(
          output: 'Invalid file name: "$name"', isError: true);
    }

    if (context.workspaceRepository == null ||
        context.contentRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);
      final matches = nodes
          .where(
              (n) => n.name == name && n.parentId == context.currentFolderId)
          .toList();

      if (matches.isEmpty) {
        return CommandResult(
            output: 'No such file: "$name"', isError: true);
      }

      final node = matches.first;
      if (node.isFolder) {
        return CommandResult(
            output: '"$name" is a directory. Use rmdir.', isError: true);
      }

      await context.contentRepository!
          .deleteContent(context.activeProject!.id, node.id);
      await context.workspaceRepository!.deleteNode(node.id);

      return CommandResult(output: 'Removed: $name');
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }

  // ── rmdir ─────────────────────────────────────────────────────────────

  Future<CommandResult> _rmdir(
      List<String> args, CommandContext context) async {
    if (context.activeProject == null) {
      return const CommandResult(
          output: 'No active project.', isError: true);
    }
    if (args.isEmpty) {
      return const CommandResult(
          output: 'Usage: rmdir <dir>', isError: true);
    }

    final name = args.first;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      return CommandResult(
          output: 'Invalid directory name: "$name"', isError: true);
    }

    if (context.workspaceRepository == null) {
      return const CommandResult(
          output: 'Workspace not available.', isError: true);
    }

    try {
      final nodes = await context.workspaceRepository!
          .getNodesForProject(context.activeProject!.id);
      final matches = nodes
          .where(
              (n) => n.name == name && n.parentId == context.currentFolderId)
          .toList();

      if (matches.isEmpty) {
        return CommandResult(
            output: 'No such directory: "$name"', isError: true);
      }

      final node = matches.first;
      if (!node.isFolder) {
        return CommandResult(
            output: '"$name" is a file, not a directory.', isError: true);
      }

      final hasChildren = nodes.any((n) => n.parentId == node.id);
      if (hasChildren) {
        return CommandResult(
            output: '"$name" is not empty.', isError: true);
      }

      await context.workspaceRepository!.deleteNode(node.id);

      return CommandResult(output: 'Removed directory: $name/');
    } on NomadException catch (e) {
      return CommandResult(output: 'Error: ${e.message}', isError: true);
    } catch (e) {
      return CommandResult(output: 'Error: $e', isError: true);
    }
  }
  String _guessMime(String ext) {
    const map = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'svg': 'image/svg+xml',
      'ico': 'image/x-icon',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'ttf': 'font/ttf',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'wasm': 'application/wasm',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
