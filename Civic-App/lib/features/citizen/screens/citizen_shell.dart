// lib/features/citizen/screens/citizen_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/swipe_navigation_wrapper.dart';

class CitizenShell extends StatelessWidget {
  final Widget child;
  const CitizenShell({super.key, required this.child});

  /// Returns the selected index for the two real tab routes only.
  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/citizen/home')) return 0;
    if (loc.startsWith('/citizen/my-issues')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idx = _selectedIndex(context);

    return Scaffold(
      body: SwipeNavigationWrapper(
        enableSwipeBack: false,
        child: child,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.2))),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/citizen/home');
                break;
              case 1:
                context.go('/citizen/my-issues');
                break;
              // case 2 = Report (push on top, doesn't live in shell)
              case 2:
                context.push('/citizen/notifications');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt_rounded),
              label: 'My Issues',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}
