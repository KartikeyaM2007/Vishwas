// lib/features/citizen/screens/citizen_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/issue_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/category_chip.dart';
import '../../issues/models/category.dart';
import '../../issues/models/issue.dart';
import '../../issues/providers/issue_providers.dart';
import '../../auth/controllers/auth_controller.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});
  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  bool _loading = true;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _simulateLoad();
  }

  Future<void> _simulateLoad() async {
    await Future.delayed(AppConstants.mockLoadDelay);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onRefresh() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loading = false);
  }

  List<Issue> _filtered(List<Issue> all) {
    if (_selectedCategoryId == null) return all;
    return all.where((i) => i.category.id == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allIssuesAsync = ref.watch(allIssuesProvider);
    final allIssues = allIssuesAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <Issue>[],
    );
    final filtered = _filtered(allIssues);
    final nearby = allIssues.take(5).toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_city_rounded, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(builder: (context) {
                    final auth = ref.watch(authControllerProvider);
                    final name = auth.user?.name ?? '';
                    final greeting = name.isNotEmpty
                        ? 'Hi, ${name.split(' ').first}'
                        : 'CityPulse';
                    return Text(
                      greeting,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                  Text(
                    'Report city issues',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(themeControllerProvider.notifier).toggle(context),
            icon: AnimatedSwitcher(
              duration: AppConstants.animFast,
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            onPressed: () => context.push('/citizen/notifications'),
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Hero(
                        tag: 'search_field',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Search by area, type...',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Category chips
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: IssueCategories.all.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return FilterChip(
                              label: const Text('All'),
                              selected: _selectedCategoryId == null,
                              onSelected: (_) => setState(() => _selectedCategoryId = null),
                              showCheckmark: false,
                            );
                          }
                          final cat = IssueCategories.all[index - 1];
                          return CategoryChip(
                            category: cat,
                            selected: _selectedCategoryId == cat.id,
                            onTap: () => setState(() {
                              _selectedCategoryId = _selectedCategoryId == cat.id ? null : cat.id;
                            }),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Recent Issues',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Issues list or empty state
            if (_loading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const IssueCardSkeleton(),
                    childCount: 3,
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.maps_home_work_outlined,
                  title: _selectedCategoryId == null
                      ? 'No issues reported yet'
                      : 'No issues in this category',
                  subtitle: _selectedCategoryId == null
                      ? 'Be the first to report a problem in your area.'
                      : 'Try a different category or report a new issue.',
                  actionLabel: _selectedCategoryId != null ? 'Clear filter' : null,
                  onAction: _selectedCategoryId != null
                      ? () => setState(() => _selectedCategoryId = null)
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => IssueCard(issue: filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/citizen/report'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report Issue'),
      ),
    );
  }
}
