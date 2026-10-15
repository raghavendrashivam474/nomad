import 'package:flutter/foundation.dart';
import 'package:nomad_core/nomad_core.dart';

import 'command_dispatcher.dart';

/// Manages terminal state, output buffering, and command execution.
class TerminalController extends ChangeNotifier {
  final CommandDispatcher _dispatcher;
  final WorkspaceRepository _workspaceRepository;
  final FileContentRepository _contentRepository;

  Project? _activeProject;
  final List<String> _outputLines = [];
  final List<PathSegment> _cwdStack = [];

  static const int maxLines = 500;
  static const int maxChars = 10000;

  TerminalController({
    required WorkspaceRepository workspaceRepository,
    required FileContentRepository contentRepository,
    CommandDispatcher? dispatcher,
  })  : _workspaceRepository = workspaceRepository,
        _contentRepository = contentRepository,
        _dispatcher = dispatcher ?? CommandDispatcher();

  // ── Public getters ────────────────────────────────────

  Project? get activeProject => _activeProject;
  WorkspaceRepository get workspaceRepository => _workspaceRepository;
  FileContentRepository get contentRepository => _contentRepository;
  List<String> get outputLines => List.unmodifiable(_outputLines);
  List<PathSegment> get cwdStack => List.unmodifiable(_cwdStack);

  String get cwdRelativePath {
    if (_cwdStack.isEmpty) return '';
    return '/${_cwdStack.map((s) => s.name).join('/')}';
  }

  String get cwdDisplayPath {
    if (_activeProject == null) return '/ (no active project)';
    return '/project/${_activeProject!.name}$cwdRelativePath';
  }

  EntityId? get currentFolderId =>
      _cwdStack.isEmpty ? null : _cwdStack.last.id;

  // ── Project binding ───────────────────────────────────

  void setActiveProject(Project? project) {
    _activeProject = project;
    _cwdStack.clear();
    _outputLines.clear();
    notifyListeners();
  }

  // ── Command execution ─────────────────────────────────

  Future<void> executeCommand(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    appendOutput('> $trimmed');

    final context = CommandContext(
      activeProject: _activeProject,
      cwdDisplayPath: cwdDisplayPath,
      currentFolderId: currentFolderId,
      cwdStack: List.unmodifiable(_cwdStack),
      workspaceRepository: _workspaceRepository,
      contentRepository: _contentRepository,
    );

    try {
      final result = await _dispatcher.dispatch(trimmed, context);

      if (result.shouldClear) {
        clearOutput();
        return;
      }

      _applyNavigation(result);

      if (result.output.isNotEmpty) {
        appendOutput(result.output, isError: result.isError);
      }
    } catch (e) {
      appendOutput('Error: $e', isError: true);
    }
  }

  // ── Navigation ────────────────────────────────────────

  void _applyNavigation(CommandResult result) {
    switch (result.navigation) {
      case NavigationAction.none:
        break;
      case NavigationAction.resetToRoot:
        _cwdStack.clear();
        notifyListeners();
        break;
      case NavigationAction.popFolder:
        if (_cwdStack.isNotEmpty) {
          _cwdStack.removeLast();
          notifyListeners();
        }
        break;
      case NavigationAction.pushFolder:
        if (result.targetFolderId != null &&
            result.targetFolderName != null) {
          _cwdStack.add(
              PathSegment(result.targetFolderId!, result.targetFolderName!));
          notifyListeners();
        }
        break;
    }
  }

  // ── Output management ─────────────────────────────────

  void appendOutput(String text, {bool isError = false}) {
    final prefix = isError ? '! ' : '';
    final lines = text.split('\n');
    for (final line in lines) {
      _outputLines.add('$prefix$line');
    }
    _enforceLimits();
    notifyListeners();
  }

  void clearOutput() {
    _outputLines.clear();
    notifyListeners();
  }

  void _enforceLimits() {
    while (_outputLines.length > maxLines) {
      _outputLines.removeAt(0);
    }
    int totalChars =
        _outputLines.fold(0, (sum, line) => sum + line.length + 1);
    while (totalChars > maxChars && _outputLines.isNotEmpty) {
      totalChars -= _outputLines.first.length + 1;
      _outputLines.removeAt(0);
    }
  }

  @override
  void dispose() {
    _outputLines.clear();
    _cwdStack.clear();
    super.dispose();
  }
}