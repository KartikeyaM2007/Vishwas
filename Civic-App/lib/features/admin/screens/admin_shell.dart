// lib/features/admin/screens/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/swipe_navigation_wrapper.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  int _selectedIndex(String path) {
    if (path.startsWith('/admin/dashboard')) return 0;
    if (path.startsWith('/admin/issues')) return 1;
    if (path.startsWith('/admin/analytics')) return 2;
    if (path.startsWith('/admin/map')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final idx = _selectedIndex(loc);
    final auth = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 720;

    final navItems = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard', '/admin/dashboard'),
      (Icons.list_alt_rounded, Icons.list_alt_outlined, 'Issues', '/admin/issues'),
      (Icons.analytics_rounded, Icons.analytics_outlined, 'Analytics', '/admin/analytics'),
      (Icons.map_rounded, Icons.map_outlined, 'Map View', '/admin/map'),
    ];

    if (isWide) {
      // NavigationDrawer (persistent) for tablets
      return Scaffold(
        body: Row(
          children: [
            NavigationDrawer(
              selectedIndex: idx,
              onDestinationSelected: (i) => context.go(navItems[i].$4),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_city_rounded, color: scheme.primary, size: 20)),
                      const SizedBox(width: 10),
                      Text('CityPulse Admin', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Divider(),
                ...navItems.map((item) => NavigationDrawerDestination(icon: Icon(item.$2), selectedIcon: Icon(item.$1), label: Text(item.$3))),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                   onTap: () async {
                     await ref.read(authControllerProvider.notifier).logout();
                     if (context.mounted) context.go('/welcome');
                   },
                ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Bottom nav for phones
    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[idx].$3),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => ref.read(themeControllerProvider.notifier).toggle(context),
          ),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: '',
                enabled: false,
                child: ListTile(
                  leading: CircleAvatar(child: Text(auth.user?.initials ?? 'A', style: const TextStyle(fontSize: 12))),
                  title: Text(auth.user?.name ?? 'Admin'),
                  subtitle: Text(auth.user?.email ?? ''),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18), SizedBox(width: 10), Text('Logout')])),
            ],
            onSelected: (v) async {
              if (v == 'logout') {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/welcome');
              }
            },
          ),
        ],
      ),
      body: SwipeNavigationWrapper(
        enableSwipeBack: false, // Disable swipe back on shell routes
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(navItems[i].$4),
        destinations: navItems.map((item) => NavigationDestination(
          icon: Icon(item.$2),
          selectedIcon: Icon(item.$1),
          label: item.$3,
        )).toList(),
      ),
    );
  }
}
