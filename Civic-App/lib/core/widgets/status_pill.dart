// lib/core/widgets/status_pill.dart
import 'package:flutter/material.dart';
import '../../features/issues/models/issue_status.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final IssueStatus status;
  final bool compact;

  const StatusPill({super.key, required this.status, this.compact = false});

  Color _bg(BuildContext context) {
    switch (status) {
      case IssueStatus.open:
        return AppTheme.statusOpen.withOpacity(0.12);
      case IssueStatus.inProgress:
        return AppTheme.statusInProgress.withOpacity(0.12);
      case IssueStatus.resolved:
        return AppTheme.statusResolved.withOpacity(0.12);
      case IssueStatus.rejected:
        return AppTheme.statusRejected.withOpacity(0.12);
    }
  }

  Color _fg() {
    switch (status) {
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

  IconData _icon() {
    switch (status) {
      case IssueStatus.open:
        return Icons.radio_button_checked_rounded;
      case IssueStatus.inProgress:
        return Icons.autorenew_rounded;
      case IssueStatus.resolved:
        return Icons.check_circle_rounded;
      case IssueStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fg();
    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: _bg(context),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(), size: compact ? 10 : 12, color: fg),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
