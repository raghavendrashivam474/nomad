import 'package:flutter/material.dart';
import '../../activity/activity_controller.dart';
import 'activity_tile.dart';

/// Lightweight panel surface displaying Live Activity events in real-time.
class LiveActivityPanel extends StatelessWidget {
  final ActivityController controller;
  final VoidCallback? onClose;
  final void Function(String sourceUri, int? line, int? column)? onNavigateToSource;

  const LiveActivityPanel({
    super.key,
    required this.controller,
    this.onClose,
    this.onNavigateToSource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final events = controller.events.reversed.toList(); // newest first

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, theme, events.length),
            const Divider(height: 1),
            Expanded(
              child: events.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildEventList(events),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 18),
          const SizedBox(width: 6),
          Text(
            'Live Activity',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          const Spacer(),
          if (count > 0)
            IconButton(
              key: const Key('activity_clear_button'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              tooltip: 'Clear activity',
              visualDensity: VisualDensity.compact,
              onPressed: controller.clear,
            ),
          if (onClose != null)
            IconButton(
              key: const Key('activity_close_button'),
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Close panel',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      key: const Key('activity_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 40,
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No activity recorded yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preview lifecycle, resource loading, and runtime errors will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<dynamic> events) {
    return ListView.builder(
      key: const Key('activity_event_list'),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ActivityTile(
          key: ValueKey(event.id),
          event: event,
          onDismiss: () => controller.dismiss(event.id),
          onNavigate: onNavigateToSource,
        );
      },
    );
  }
}