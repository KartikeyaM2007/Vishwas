// lib/features/common/screens/global_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/issue_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/models/issue.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../issues/models/issue_status.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    // Auto focus
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_focusNode));
  }

  final _focusNode = FocusNode();

  void _onSearch() {
    if (mounted) setState(() => _query = _searchCtrl.text);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(issueRepositoryProvider);
    final auth = ref.watch(authControllerProvider);
    final isAdmin = auth.role == UserRole.admin;

    final results = _query.trim().length >= 2
        ? repo.searchIssues(_query)
        : <Issue>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Hero(
          tag: 'search_field',
          child: Material(
            color: Colors.transparent,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search issues, areas, categories...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppConstants.animMedium,
        child: _query.trim().length < 2
            ? _buildEmptyPrompt(context, scheme)
            : results.isEmpty
                ? EmptyState(
                    key: const ValueKey('no_results'),
                    icon: Icons.search_off_rounded,
                    title: 'No results for "$_query"',
                    subtitle: 'Try a different keyword or area name.',
                  )
                : ListView.builder(
                    key: const ValueKey('results'),
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (_, i) => IssueCard(issue: results[i], isAdmin: isAdmin),
                  ),
      ),
    );
  }

  Widget _buildEmptyPrompt(BuildContext context, ColorScheme scheme) {
    return Padding(
      key: const ValueKey('prompt'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Search tips', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ...[
            ('Try area names', 'Koramangala, Whitefield, HSR Layout'),
            ('Try category names', 'Road, Water, Garbage, Electricity'),
            ('Try keywords', 'pothole, streetlight, drain, tree'),
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(tip.$2, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
