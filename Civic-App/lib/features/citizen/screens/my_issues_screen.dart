// lib/features/citizen/screens/my_issues_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/issue_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/issue_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class MyIssuesScreen extends ConsumerStatefulWidget {
  const MyIssuesScreen({super.key});
  @override
  ConsumerState<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends ConsumerState<MyIssuesScreen> {
  bool _loading = true;
  IssueStatus? _filterStatus;
  SortOrder _sortOrder = SortOrder.latest;

  @override
  void initState() {
    super.initState();
    Future.delayed(AppConstants.mockLoadDelay, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myIssuesAsync = ref.watch(myIssuesProvider);

    final statuses = [null, ...IssueStatus.values];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Issues'),
        actions: [
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => _sortOrder = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: SortOrder.latest, child: Text('Latest first', style: TextStyle(fontWeight: _sortOrder == SortOrder.latest ? FontWeight.w700 : null))),
              PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest first', style: TextStyle(fontWeight: _sortOrder == SortOrder.oldest ? FontWeight.w700 : null))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = statuses[index];
                final label = s == null ? 'All' : s.label;
                final isSelected = _filterStatus == s;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filterStatus = s),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // Issues list
          Expanded(
            child: myIssuesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const IssueCardSkeleton(),
              ),
              error: (err, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load issues',
                subtitle: err.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(myIssuesProvider),
              ),
              data: (issues) {
                // Apply status filter
                var filtered = issues;
                if (_filterStatus != null) {
                  filtered = filtered.where((i) => i.status == _filterStatus).toList();
                }

                // Apply sorting
                filtered = List.from(filtered);
                if (_sortOrder == SortOrder.latest) {
                  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                } else {
                  filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.list_alt_rounded,
                    title: _filterStatus == null ? 'No issues yet' : 'No ${_filterStatus!.label} issues',
                    subtitle: _filterStatus == null
                        ? 'Tap the Report button to submit your first issue.'
                        : 'Try a different status filter.',
                    actionLabel: _filterStatus == null ? null : 'Clear filter',
                    onAction: _filterStatus == null ? null : () => setState(() => _filterStatus = null),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myIssuesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => IssueCard(issue: filtered[i]),
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
