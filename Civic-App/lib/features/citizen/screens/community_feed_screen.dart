import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/issue_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/providers/issue_providers.dart';

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() =>
      _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  IssueStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(allIssuesProvider);
    final statuses = [null, ...IssueStatus.values];

    return Scaffold(
      appBar: AppBar(title: const Text('Community Feed')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemBuilder: (context, index) {
                final status = statuses[index];
                return FilterChip(
                  label: Text(status?.label ?? 'All'),
                  selected: _filterStatus == status,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filterStatus = status),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: statuses.length,
            ),
          ),
          Expanded(
            child: issuesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const IssueCardSkeleton(),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load community feed',
                subtitle: error.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(allIssuesProvider),
              ),
              data: (issues) {
                final filtered = _filterStatus == null
                    ? issues
                    : issues
                        .where((issue) => issue.status == _filterStatus)
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No reports here yet',
                    subtitle: _filterStatus == null
                        ? 'Community reports will appear here.'
                        : 'Try a different status filter.',
                    actionLabel: _filterStatus == null ? null : 'Clear filter',
                    onAction: _filterStatus == null
                        ? null
                        : () => setState(() => _filterStatus = null),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(allIssuesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) => IssueCard(issue: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
