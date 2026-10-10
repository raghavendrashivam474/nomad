import 'package:flutter/material.dart';
import '../../activity/activity_event.dart';

/// Renders a single activity event in a compact, expandable tile.
class ActivityTile extends StatefulWidget {
  final ActivityEvent event;
  final VoidCallback onDismiss;
  final void Function(String sourceUri, int? line, int? column)? onNavigate;

  const ActivityTile({
    super.key,
    required this.event,
    required this.onDismiss,
    this.onNavigate,
  });

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;

    final (icon, color, bgColor) = _severityStyle(event.severity, theme);
    final hasDetails = (event.details != null && event.details!.isNotEmpty) ||
        event.sourceUri != null;

    final timeStr = _formatTime(event.timestamp);

    return Card(
      key: Key('activity_tile_${event.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: color.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _categoryBadge(event.category, theme),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasDetails)
                  IconButton(
                    key: Key('activity_expand_${event.id}'),
                    icon: Icon(
                      _isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: _isExpanded ? 'Collapse' : 'Expand details',
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                  ),
                IconButton(
                  key: Key('activity_dismiss_${event.id}'),
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Dismiss',
                  onPressed: widget.onDismiss,
                ),
              ],
            ),
            if (_isExpanded && hasDetails) ...[
              const Divider(height: 12),
              if (event.details != null && event.details!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: SelectableText(
                    event.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (event.sourceUri != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _formatLocation(event.sourceUri!, event.line, event.column),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onNavigate != null)
                      TextButton.icon(
                        key: Key('activity_navigate_${event.id}'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Open Source', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          widget.onNavigate!(event.sourceUri!, event.line, event.column);
                        },
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _severityStyle(
      ActivitySeverity severity, ThemeData theme) {
    switch (severity) {
      case ActivitySeverity.info:
        return (
          Icons.info_outline,
          Colors.blueAccent,
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        );
      case ActivitySeverity.warning:
        return (
          Icons.warning_amber_rounded,
          Colors.amber,
          Colors.amber.withValues(alpha: 0.08),
        );
      case ActivitySeverity.error:
        return (
          Icons.error_outline,
          theme.colorScheme.error,
          theme.colorScheme.errorContainer.withValues(alpha: 0.2),
        );
    }
  }

  Widget _categoryBadge(ActivityCategory category, ThemeData theme) {
    final String text;
    switch (category) {
      case ActivityCategory.lifecycle:
        text = 'LIFECYCLE';
      case ActivityCategory.resource:
        text = 'RESOURCE';
      case ActivityCategory.runtime:
        text = 'RUNTIME';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatLocation(String uri, int? line, int? col) {
    if (line == null) return uri;
    if (col == null) return '$uri:$line';
    return '$uri:$line:$col';
  }
}