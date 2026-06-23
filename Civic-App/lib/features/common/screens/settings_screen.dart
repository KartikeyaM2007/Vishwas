import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../issues/models/issue_status.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isAdmin = auth.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          _SectionHeader('Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                color: scheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              user?.name.isNotEmpty == true ? user!.name : 'Anonymous User',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              user?.email.isNotEmpty == true ? user!.email : 'No email set',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAdmin
                    ? Colors.purple.withValues(alpha: 0.1)
                    : scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                isAdmin ? 'Admin' : 'Citizen',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isAdmin ? Colors.purple : scheme.primary,
                ),
              ),
            ),
          ),

          _SectionHeader('Role'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch between Citizen and Admin mode',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.citizen,
                      icon: Icon(Icons.person_rounded, size: 16),
                      label: Text('Citizen'),
                    ),
                    ButtonSegment(
                      value: UserRole.admin,
                      icon: Icon(Icons.admin_panel_settings_rounded, size: 16),
                      label: Text('Admin'),
                    ),
                  ],
                  selected: {auth.role ?? UserRole.citizen},
                  onSelectionChanged: (v) async {
                    final selected = v.first;
                    if (selected == UserRole.admin) {
                      await ref.read(authControllerProvider.notifier).switchToAdmin();
                    } else {
                      await ref.read(authControllerProvider.notifier).switchToCitizen();
                    }
                    if (context.mounted) {
                      context.go(selected == UserRole.admin ? '/admin/dashboard' : '/citizen/home');
                    }
                  },
                ),
              ],
            ),
          ),

          _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.phone_android_rounded, size: 16),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 16),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 16),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (v) {
                    ref.read(themeControllerProvider.notifier).setTheme(v.first);
                  },
                ),
              ],
            ),
          ),

          _SectionHeader('Account'),
          ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout_rounded, color: scheme.error, size: 18),
            ),
            title: Text('Sign Out', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
            subtitle: const Text('You will need to sign in again'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: scheme.error),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/welcome');
              }
            },
          ),

          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_city_rounded, color: scheme.primary, size: 20),
            ),
            title: const Text('CityPulse'),
            subtitle: const Text('Citizen Issue Portal'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('App Version'),
            trailing: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),

          const SizedBox(height: 40),

          Center(
            child: Text(
              'CityPulse — Citizen Issue Portal',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
