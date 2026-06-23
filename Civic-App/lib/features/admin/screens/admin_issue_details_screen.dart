// lib/features/admin/screens/admin_issue_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/timeline_stepper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipe_navigation_wrapper.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/models/issue_status.dart';

class AdminIssueDetailsScreen extends ConsumerStatefulWidget {
  final String issueId;
  const AdminIssueDetailsScreen({super.key, required this.issueId});
  @override
  ConsumerState<AdminIssueDetailsScreen> createState() => _AdminIssueDetailsScreenState();
}

class _AdminIssueDetailsScreenState extends ConsumerState<AdminIssueDetailsScreen> {
  IssueStatus? _selectedStatus;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a new status.')),
      );
      return;
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final repo = ref.read(issueRepositoryProvider);
    repo.updateIssueStatus(
      widget.issueId,
      _selectedStatus!,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    setState(() => _saving = false);
    _noteCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Status updated to ${_selectedStatus!.label}'),
          ]),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(issueByIdProvider(widget.issueId));
    final repo = ref.watch(issueRepositoryProvider);

    return issueAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(child: Text('Error loading issue.')),
      ),
      data: (issue) {
        if (issue == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Issue Details')),
            body: const EmptyState(icon: Icons.search_off_rounded, title: 'Issue not found'),
          );
        }

        final history = repo.getIssueHistory(widget.issueId);
        final scheme = Theme.of(context).colorScheme;
        final cat = issue.category;
        final dateStr = DateFormat('d MMM y, h:mm a').format(issue.createdAt);

        _selectedStatus ??= issue.status;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Issue Details'),
            backgroundColor: cat.color.withOpacity(0.1),
          ),
          body: SwipeNavigationWrapper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cat.color.withOpacity(0.12), cat.color.withOpacity(0.04)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cat.color.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: cat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Icon(cat.icon, color: cat.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat.name, style: TextStyle(fontSize: 11, color: cat.color, fontWeight: FontWeight.w600)),
                                  Text(issue.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            StatusPill(status: issue.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Info(icon: Icons.location_on_rounded, text: issue.location.displayName),
                        _Info(icon: Icons.calendar_today_rounded, text: dateStr),
                        _Info(icon: Icons.tag_rounded, text: 'Issue ID: ${issue.id}'),
                      ]),
                  ),

                  const SizedBox(height: 20),

                  // Reporter info
                  Text('Reporter Info', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            issue.reporterName.isNotEmpty ? issue.reporterName[0].toUpperCase() : 'C',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(issue.reporterName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('Citizen • ID: ${issue.reporterId}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.verified_user_rounded, size: 18, color: scheme.primary),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text('Description', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(issue.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.6)),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Admin actions
                  Text('Update Status', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IssueStatus>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'New Status',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: IssueStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Internal Note (optional)',
                      hintText: 'Add a note for this status change...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: const Text('Save Changes'),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  Text('Status History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TimelineStepper(history: history),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}
