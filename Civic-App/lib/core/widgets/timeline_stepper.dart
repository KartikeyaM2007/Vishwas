// lib/core/widgets/timeline_stepper.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/issues/models/issue.dart';
import '../../features/issues/models/issue_status.dart';
import '../theme/app_theme.dart';

class TimelineStepper extends StatelessWidget {
  final List<IssueStatusHistory> history;

  const TimelineStepper({super.key, required this.history});

  Color _colorForStatus(IssueStatus s) {
    switch (s) {
      case IssueStatus.open:
        return AppTheme.statusOpen;
      case IssueStatus.inProgress:
        return AppTheme.statusInProgress;
      case IssueStatus.resolved:
        return AppTheme.statusResolved;
      case IssueStatus.rejected:
        return AppTheme.statusRejected;
    }
  }

  IconData _iconForStatus(IssueStatus s) {
    switch (s) {
      case IssueStatus.open:
        return Icons.flag_rounded;
      case IssueStatus.inProgress:
        return Icons.engineering_rounded;
      case IssueStatus.resolved:
        return Icons.check_circle_rounded;
      case IssueStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: List.generate(history.length, (index) {
        final entry = history[index];
        final isLast = index == history.length - 1;
        final color = _colorForStatus(entry.newStatus);
        final dateStr = DateFormat('d MMM y, h:mm a').format(entry.changedAt);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: icon + line
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(_iconForStatus(entry.newStatus), size: 16, color: color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: scheme.outlineVariant.withOpacity(0.4),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.newStatus.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (entry.changedBy.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'By ${entry.changedBy}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                      if (entry.note != null && entry.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.note!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
