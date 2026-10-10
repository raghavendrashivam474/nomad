import 'package:flutter/foundation.dart';

import 'activity_event.dart';

/// Lightweight, in-memory activity state for the Live Activity panel.
///
/// Responsibilities:
/// - Accept events from preview, server, and runtime sources.
/// - Reject stale events from previous preview sessions.
/// - Bound history to [maxEvents] (evicts oldest).
/// - Support dismiss and clear without mutating project or preview state.
///
/// This is the **only** mutable state holder for WX-3 activity.
/// It intentionally does not persist events, run timers, or own a WebView.
class ActivityController extends ChangeNotifier {
  /// Default upper bound on retained events.
  static const int defaultMaxEvents = 200;

  /// Configurable ceiling; useful for testing with small values.
  final int maxEvents;

  final List<ActivityEvent> _events = [];
  int _sessionId = 0;
  int _nextId = 0;

  ActivityController({this.maxEvents = defaultMaxEvents})
      : assert(maxEvents > 0, 'maxEvents must be positive');

  // ── Read API ──────────────────────────────────────────────

  /// Unmodifiable snapshot of current events in insertion order
  /// (oldest first). The UI should reverse for display if newest-first
  /// is desired.
  List<ActivityEvent> get events => List.unmodifiable(_events);

  /// The active preview session identifier.
  int get currentSessionId => _sessionId;

  /// Number of retained events.
  int get length => _events.length;

  // ── Session lifecycle ─────────────────────────────────────

  /// Begin a new preview session.
  ///
  /// Increments [currentSessionId] so that any future [add] call carrying
  /// the old session id is silently dropped (stale-callback guard).
  /// Does **not** clear existing events — the user may still want to see
  /// recent history from the previous session.
  int beginSession() {
    _sessionId++;
    _nextId = 0;
    return _sessionId;
  }

  // ── Write API ─────────────────────────────────────────────

  /// Add an externally-created event.
  ///
  /// Silently drops the event if its [ActivityEvent.sessionId] does not
  /// match [currentSessionId]. This is the primary defence against stale
  /// async callbacks from a disposed or replaced preview.
  void add(ActivityEvent event) {
    if (event.sessionId != _sessionId) return;

    _events.add(event);

    // Evict oldest until within bounds.
    while (_events.length > maxEvents) {
      _events.removeAt(0);
    }

    notifyListeners();
  }

  /// Convenience factory that stamps [id], [timestamp], and [sessionId]
  /// automatically. Sources should prefer this over manual construction
  /// to guarantee correct session association.
  ActivityEvent createEvent({
    required ActivityCategory category,
    required ActivitySeverity severity,
    required String message,
    String? details,
    String? sourceUri,
    int? line,
    int? column,
  }) {
    return ActivityEvent(
      id: '$_sessionId-${_nextId++}',
      timestamp: DateTime.now(),
      category: category,
      severity: severity,
      message: message,
      details: details,
      sourceUri: sourceUri,
      line: line,
      column: column,
      sessionId: _sessionId,
    );
  }

  /// Remove a single event by [id].
  ///
  /// This is a UI/history operation. It does not affect the running
  /// preview, project files, or future event collection.
  void dismiss(String id) {
    final before = _events.length;
    _events.removeWhere((e) => e.id == id);
    if (_events.length != before) {
      notifyListeners();
    }
  }

  /// Remove all visible events.
  ///
  /// Does not reset the session, stop the preview, or suppress future
  /// events. Closing the activity panel should **not** call this.
  void clear() {
    if (_events.isEmpty) return;
    _events.clear();
    notifyListeners();
  }
}
