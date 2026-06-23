// lib/features/citizen/screens/issue_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/timeline_stepper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipe_navigation_wrapper.dart';
import '../../issues/providers/issue_providers.dart';

class IssueDetailsScreen extends ConsumerWidget {
  final String issueId;
  const IssueDetailsScreen({super.key, required this.issueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issueAsync = ref.watch(issueByIdProvider(issueId));
    final repo = ref.watch(issueRepositoryProvider);

    return issueAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load issue',
          subtitle: 'Please try again later.',
        ),
      ),
      data: (issue) {
        if (issue == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Issue not found',
              subtitle: 'This issue may have been removed.',
            ),
          );
        }

        final history = repo.getIssueHistory(issueId);
        final scheme = Theme.of(context).colorScheme;
        final cat = issue.category;
        final dateStr =
            DateFormat('MMMM d, yyyy — h:mm a').format(issue.createdAt);

        return Scaffold(
          body: SwipeNavigationWrapper(
            child: CustomScrollView(
              slivers: [
                // Hero SliverAppBar
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: Hero(
                    tag: 'issue_${issue.id}',
                    child: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cat.color.withOpacity(0.8),
                              cat.color.withOpacity(0.4),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            if (issue.attachments.isNotEmpty &&
                                issue.attachments.first.startsWith('http'))
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.6,
                                  child: Image.network(
                                    issue.attachments.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                  ),
                                ),
                              )
                            else 
                              Positioned(
                                right: -20,
                                bottom: -20,
                                child: Icon(
                                  cat.icon,
                                  size: 140,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          cat.icon,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          cat.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share link copied! (mock)'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status + title
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                issue.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusPill(status: issue.status),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Meta row
                        _MetaRow(
                          icon: Icons.location_on_rounded,
                          text: issue.location.displayName,
                        ),
                        const SizedBox(height: 6),
                        _MetaRow(
                          icon: Icons.calendar_today_rounded,
                          text: dateStr,
                        ),
                        _MetaRow(
                          icon: Icons.person_rounded,
                          text: 'Reported by ${issue.reporterName}',
                        ),

                        const Divider(height: 32),

                        Text(
                          'Description',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          issue.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                height: 1.6,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),

                        const Divider(height: 32),

                        // Attachments carousel (mock)
                        Text(
                          'Attachments',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (issue.attachments.isEmpty)
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No attachments',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: issue.attachments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, i) => Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: (issue.attachments[i].startsWith('http')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            issue.attachments[i],
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.image_not_supported_rounded,
                                              color: cat.color,
                                              size: 36,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.image_rounded,
                                          color: cat.color,
                                          size: 36,
                                        )),
                              ),
                            ),
                          ),

                        const Divider(height: 32),

                        Text(
                          'Status Timeline',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        TimelineStepper(history: history),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
