import 'package:flutter/foundation.dart';

/// Broad classification of an activity event.
enum ActivityCategory {
  /// Preview loading, navigation, session transitions.
  lifecycle,

  /// Resource resolution or loading failures observed by the server or WebView.
  resource,

  /// JavaScript exceptions or warnings from the running preview.
  runtime,
}

/// User-facing severity.
enum ActivitySeverity {
  info,
  warning,
  error,
}

/// A single observable event from the preview, server, or runtime.
///
/// Immutable. Identity is based solely on [id].
@immutable
class ActivityEvent {
  /// Unique within the lifetime of the application process.
  final String id;

  /// When the event was observed (wall-clock).
  final DateTime timestamp;

  final ActivityCategory category;
  final ActivitySeverity severity;

  /// Short human-readable summary (one line).
  final String message;

  /// Optional long-form diagnostic detail (stack, URL, etc.).
  final String? details;

  /// Optional project-relative file path or URL.
  final String? sourceUri;

  /// Optional 1-based line number for source navigation.
  final int? line;

  /// Optional 1-based column number for source navigation.
  final int? column;

  /// The preview session that produced this event.
  /// Used to reject stale callbacks after a new preview load.
  final int sessionId;

  const ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.message,
    this.details,
    this.sourceUri,
    this.line,
    this.column,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityEvent && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ActivityEvent($id, $category, $severity, "$message", session=$sessionId)';
}
