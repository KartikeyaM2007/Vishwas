// lib/features/admin/screens/admin_issues_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/issue_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../issues/models/issue.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/models/category.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/issue_repository.dart';

class AdminIssuesScreen extends ConsumerStatefulWidget {
  const AdminIssuesScreen({super.key});
  @override
  ConsumerState<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends ConsumerState<AdminIssuesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  IssueStatus? _filterStatus;
  String? _filterCategoryId;
  SortOrder _sortOrder = SortOrder.latest;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final issuesAsync = ref.watch(allIssuesProvider);

    // Apply screen-level search + filters on top of remote list.
    final q = _query.toLowerCase().trim();
    List<Issue> applyView(List<Issue> issues) {
      var view = issues;
      if (_filterStatus != null) {
        view = view.where((i) => i.status == _filterStatus).toList();
      }
      if (_filterCategoryId != null && _filterCategoryId!.isNotEmpty) {
        view = view.where((i) => i.category.id == _filterCategoryId).toList();
      }
      if (q.isNotEmpty) {
        view = view.where((i) {
          return i.title.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q) ||
              i.location.areaName.toLowerCase().contains(q) ||
              i.category.name.toLowerCase().contains(q);
        }).toList();
      }
      if (_sortOrder == SortOrder.oldest) {
        view.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        view.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return view;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search issues...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16), onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter row
              Row(
                children: [
                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<IssueStatus?>(
                      value: _filterStatus,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13), // Smaller font
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(fontSize: 12), // Smaller label
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Even smaller padding
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Status', style: TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ...IssueStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Category filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _filterCategoryId,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13), // Smaller font
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(fontSize: 12), // Smaller label
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Even smaller padding
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories', style: TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ...IssueCategories.all.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _filterCategoryId = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Result count + sort
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                issuesAsync.when(
                  data: (issues) {
                    final view = applyView(issues);
                    return '${view.length} issue${view.length == 1 ? '' : 's'}';
                  },
                  loading: () => 'Loading…',
                  error: (_, __) => '—',
                ),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              DropdownButton<SortOrder>(
                value: _sortOrder,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: SortOrder.latest, child: Text('Latest', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: SortOrder.oldest, child: Text('Oldest', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _sortOrder = v ?? SortOrder.latest),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: issuesAsync.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) => const IssueCardSkeleton(),
            ),
            error: (e, st) => const EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t load complaints',
              subtitle: 'Please check your connection and try again.',
            ),
            data: (issues) {
              final view = applyView(issues);
              if (view.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No issues found',
                  subtitle: 'Try adjusting your search or filters.',
                  actionLabel: 'Clear all',
                  onAction: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _filterStatus = null;
                      _filterCategoryId = null;
                    });
                  },
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: view.length,
                itemBuilder: (_, i) => IssueCard(issue: view[i], isAdmin: true),
              );
            },
          ),
        ),
      ],
    );
  }
}
