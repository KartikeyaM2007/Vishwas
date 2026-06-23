// lib/features/citizen/screens/notifications_screen.dart
import 'package:flutter/material.dart';

class _MockNotification {
  final String title;
  final String body;
  final String time;
  final bool isRead;
  final IconData icon;
  final Color color;

  const _MockNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.icon,
    required this.color,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Empty by default — notifications come from real submitted issues
  final List<_MockNotification> _notifications = [];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(unread > 0 ? 'Notifications ($unread)' : 'Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => setState(() {}),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You will receive updates when\nyour reported issues change status.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return Container(
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? scheme.surfaceContainerHighest
                        : scheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: n.isRead
                          ? scheme.outlineVariant.withValues(alpha: 0.2)
                          : scheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: n.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(n.icon, color: n.color, size: 20),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          n.body,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    trailing: !n.isRead
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
