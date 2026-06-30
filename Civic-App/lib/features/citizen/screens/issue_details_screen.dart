// lib/features/citizen/screens/issue_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/timeline_stepper.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipe_navigation_wrapper.dart';
import '../../../core/services/citizen_identity_service.dart';
import '../../issues/models/complaint_comment.dart';
import '../../issues/models/issue.dart';
import '../../issues/providers/issue_providers.dart';

class IssueDetailsScreen extends ConsumerStatefulWidget {
  final String issueId;
  final Issue? initialIssue;

  const IssueDetailsScreen({
    super.key,
    required this.issueId,
    this.initialIssue,
  });

  @override
  ConsumerState<IssueDetailsScreen> createState() => _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends ConsumerState<IssueDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final Map<int, TextEditingController> _replyControllers = {};
  bool _posting = false;

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final citizenId = await ref.read(citizenIdentityProvider.future);
      await ref.read(remoteIssueRepositoryProvider).addComment(
            complaintId: widget.issueId,
            userId: citizenId,
            username: 'Mobile Citizen',
            body: body,
          );
      _commentController.clear();
      ref.invalidate(issueCommentsProvider(widget.issueId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _postReply(ComplaintComment comment) async {
    final controller = _replyControllers[comment.id];
    final body = controller?.text.trim() ?? '';
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final citizenId = await ref.read(citizenIdentityProvider.future);
      await ref.read(remoteIssueRepositoryProvider).replyToComment(
            complaintId: widget.issueId,
            commentId: comment.id,
            userId: citizenId,
            username: 'Mobile Citizen',
            body: body,
          );
      controller?.clear();
      ref.invalidate(issueCommentsProvider(widget.issueId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(issueByIdProvider(widget.issueId));
    final repo = ref.watch(issueRepositoryProvider);

    if (widget.initialIssue != null) {
      return _SimpleIssueDetails(
        issue: widget.initialIssue!,
        commentsAsync: ref.watch(issueCommentsProvider(widget.issueId)),
        onRetryComments: () =>
            ref.invalidate(issueCommentsProvider(widget.issueId)),
        commentController: _commentController,
        replyControllers: _replyControllers,
        posting: _posting,
        onPostComment: _postComment,
        onPostReply: _postReply,
      );
    }

    return issueAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, __) => Scaffold(
        appBar: AppBar(title: const Text('Issue Details')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load issue',
          subtitle: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(issueByIdProvider(widget.issueId)),
        ),
      ),
      data: (issue) {
        if (issue == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Issue Details')),
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Issue not found',
              subtitle: 'This issue may have been removed.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(issueByIdProvider(widget.issueId)),
            ),
          );
        }

        final history = repo.getIssueHistory(widget.issueId);
        final scheme = Theme.of(context).colorScheme;
        final cat = issue.category;
        final dateStr =
            DateFormat('MMMM d, yyyy — h:mm a').format(issue.createdAt);

        return Scaffold(
          body: SwipeNavigationWrapper(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cat.color.withValues(alpha: 0.8),
                            cat.color.withValues(alpha: 0.4),
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
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(),
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
                                color: Colors.white.withValues(alpha: 0.1),
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                  color: cat.color.withValues(alpha: 0.1),
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

                        const Divider(height: 32),

                        _DiscussionSection(
                          commentsAsync:
                              ref.watch(issueCommentsProvider(widget.issueId)),
                          onRetryComments: () => ref.invalidate(
                              issueCommentsProvider(widget.issueId)),
                          commentController: _commentController,
                          replyControllers: _replyControllers,
                          posting: _posting,
                          onPostComment: _postComment,
                          onPostReply: _postReply,
                        ),

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

class _SimpleIssueDetails extends StatelessWidget {
  final Issue issue;
  final AsyncValue<List<ComplaintComment>> commentsAsync;
  final TextEditingController commentController;
  final Map<int, TextEditingController> replyControllers;
  final bool posting;
  final VoidCallback onPostComment;
  final VoidCallback onRetryComments;
  final void Function(ComplaintComment comment) onPostReply;

  const _SimpleIssueDetails({
    required this.issue,
    required this.commentsAsync,
    required this.commentController,
    required this.replyControllers,
    required this.posting,
    required this.onPostComment,
    required this.onRetryComments,
    required this.onPostReply,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMMM d, yyyy, h:mm a').format(issue.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttachmentFallback(issue: issue),
            const SizedBox(height: 18),
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
            _MetaRow(
              icon: Icons.location_on_rounded,
              text: issue.location.displayName,
            ),
            _MetaRow(icon: Icons.calendar_today_rounded, text: dateStr),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 32),
            _DiscussionSection(
              commentsAsync: commentsAsync,
              onRetryComments: onRetryComments,
              commentController: commentController,
              replyControllers: replyControllers,
              posting: posting,
              onPostComment: onPostComment,
              onPostReply: onPostReply,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  final Issue issue;

  const _AttachmentFallback({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: issue.category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        issue.category.icon,
        color: issue.category.color,
        size: 64,
      ),
    );
  }
}

class _DiscussionSection extends StatelessWidget {
  final AsyncValue<List<ComplaintComment>> commentsAsync;
  final TextEditingController commentController;
  final Map<int, TextEditingController> replyControllers;
  final bool posting;
  final VoidCallback onPostComment;
  final VoidCallback onRetryComments;
  final void Function(ComplaintComment comment) onPostReply;

  const _DiscussionSection({
    required this.commentsAsync,
    required this.commentController,
    required this.replyControllers,
    required this.posting,
    required this.onPostComment,
    required this.onRetryComments,
    required this.onPostReply,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discussion',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add a comment',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: posting ? null : onPostComment,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Post'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (error, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discussion unavailable',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRetryComments,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Discussion'),
                ),
              ],
            ),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return Text(
                'No comments yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: comments
                  .map((comment) => _CommentTile(
                        comment: comment,
                        replyControllers: replyControllers,
                        posting: posting,
                        onPostReply: onPostReply,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ComplaintComment comment;
  final Map<int, TextEditingController> replyControllers;
  final bool posting;
  final void Function(ComplaintComment comment) onPostReply;
  final int depth;

  const _CommentTile({
    required this.comment,
    required this.replyControllers,
    required this.posting,
    required this.onPostReply,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = replyControllers.putIfAbsent(
      comment.id,
      () => TextEditingController(),
    );
    final badge = comment.userRole == 'admin'
        ? 'Admin'
        : comment.isVerifiedUser
            ? 'Verified Citizen'
            : 'Citizen';
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 14, top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: depth == 0
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: depth == 0 ? 0 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.username,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.isDeleted ? '[deleted]' : comment.body,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${comment.upvotes}'),
                  const SizedBox(width: 12),
                  Icon(Icons.thumb_down_alt_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${comment.downvotes}'),
                ],
              ),
              if (depth < 2 && !comment.isDeleted) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Reply',
                          counterText: '',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: posting ? null : () => onPostReply(comment),
                      icon: const Icon(Icons.reply_rounded),
                    ),
                  ],
                ),
              ],
              ...comment.replies.map(
                (reply) => _CommentTile(
                  comment: reply,
                  replyControllers: replyControllers,
                  posting: posting,
                  onPostReply: onPostReply,
                  depth: depth + 1,
                ),
              ),
            ],
          ),
        ),
      ),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
