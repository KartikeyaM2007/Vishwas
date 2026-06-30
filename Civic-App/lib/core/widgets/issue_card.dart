// lib/core/widgets/issue_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../features/citizen/screens/issue_details_screen.dart';
import '../../features/issues/models/issue.dart';
import 'status_pill.dart';

class IssueCard extends StatelessWidget {
  final Issue issue;
  final bool isAdmin;
  final VoidCallback? onTap;

  const IssueCard({
    super.key,
    required this.issue,
    this.isAdmin = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = issue.category;
    final timeStr = _formatTime(issue.createdAt);

    return Semantics(
      label:
          '${issue.title}, ${issue.status.label}, ${issue.location.displayName}',
      button: true,
      child: GestureDetector(
        onTap: onTap ??
            () {
              if (isAdmin) {
                context.push('/admin/issue/${issue.id}', extra: issue);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IssueDetailsScreen(
                      issueId: issue.id, initialIssue: issue),
                ),
              );
            },
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: issue.isUrgent
                    ? Colors.red.withValues(alpha: 0.3)
                    : scheme.outlineVariant.withValues(alpha: 0.2),
                width: issue.isUrgent ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Urgent banner — only show when truly urgent
                  if (issue.isUrgent)
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.priority_high_rounded,
                              size: 12, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: icon + title + status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (issue.attachments.isNotEmpty &&
                                issue.attachments.first.startsWith('http'))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  issue.attachments.first,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: cat.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(cat.icon,
                                        size: 20, color: cat.color),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    Icon(cat.icon, size: 20, color: cat.color),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: cat.color,
                                      fontWeight: FontWeight.w600,
                                      overflow: TextOverflow.ellipsis,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    issue.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.1,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusPill(status: issue.status, compact: true),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Description
                        Text(
                          issue.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                        ),

                        const SizedBox(height: 6),

                        // Footer: location + time
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                issue.location.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.0,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.access_time_rounded,
                                size: 11, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.0,
                                  ),
                            ),
                          ],
                        ),

                        // Admin-only: reporter name
                        if (isAdmin && issue.reporterName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 11, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  issue.reporterName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.0,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isAdmin) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MiniChip(
                                label: _humanize(issue.validationStatus),
                                icon: Icons.verified_outlined,
                              ),
                              _MiniChip(
                                label: issue.rewardEligible
                                    ? 'Reward eligible'
                                    : 'No reward yet',
                                icon: Icons.emoji_events_outlined,
                              ),
                              _MiniChip(
                                label: issue.mediaType,
                                icon: issue.mediaType == 'video'
                                    ? Icons.videocam_outlined
                                    : Icons.image_outlined,
                              ),
                              _MiniChip(
                                label: '${issue.commentsCount} comments',
                                icon: Icons.chat_bubble_outline_rounded,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return DateFormat('d MMM y').format(dt);
    if (diff.inDays > 7) return DateFormat('d MMM').format(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _humanize(String value) {
    return value
        .replaceAll('_', ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
