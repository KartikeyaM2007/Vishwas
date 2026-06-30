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
        return const Color(0xFFF59E0B).withValues(alpha: 0.14);
      case IssueStatus.manualReview:
        return const Color(0xFFF97316).withValues(alpha: 0.14);
      case IssueStatus.approved:
        return const Color(0xFF0EA5E9).withValues(alpha: 0.14);
      case IssueStatus.needsMoreProof:
        return const Color(0xFFA855F7).withValues(alpha: 0.14);
      case IssueStatus.inProgress:
        return const Color(0xFF2563EB).withValues(alpha: 0.14);
      case IssueStatus.resolved:
        return AppTheme.statusResolved.withValues(alpha: 0.12);
      case IssueStatus.rejected:
        return AppTheme.statusRejected.withValues(alpha: 0.12);
    }
  }

  Color _fg() {
    switch (status) {
      case IssueStatus.open:
        return const Color(0xFFD97706);
      case IssueStatus.manualReview:
        return const Color(0xFFEA580C);
      case IssueStatus.approved:
        return const Color(0xFF0284C7);
      case IssueStatus.needsMoreProof:
        return const Color(0xFF9333EA);
      case IssueStatus.inProgress:
        return const Color(0xFF2563EB);
      case IssueStatus.resolved:
        return AppTheme.statusResolved;
      case IssueStatus.rejected:
        return AppTheme.statusRejected;
    }
  }

  IconData _icon() {
    switch (status) {
      case IssueStatus.open:
        return Icons.schedule_rounded;
      case IssueStatus.manualReview:
        return Icons.manage_search_rounded;
      case IssueStatus.approved:
        return Icons.verified_rounded;
      case IssueStatus.needsMoreProof:
        return Icons.add_photo_alternate_outlined;
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
