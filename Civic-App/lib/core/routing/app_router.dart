// lib/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/citizen/screens/citizen_shell.dart';
import '../../features/citizen/screens/citizen_home_screen.dart';
import '../../features/citizen/screens/community_feed_screen.dart';
import '../../features/citizen/screens/report_issue_screen.dart';
import '../../features/citizen/screens/my_issues_screen.dart';
import '../../features/citizen/screens/issue_details_screen.dart';
import '../../features/citizen/screens/notifications_screen.dart';
import '../../features/citizen/screens/leaderboard_screen.dart';
import '../../features/voice_report/screens/citizen_assistant_screen.dart';
import '../../features/voice_report/screens/voice_assisted_report_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_issues_screen.dart';
import '../../features/admin/screens/admin_issue_details_screen.dart';
import '../../features/admin/screens/admin_analytics_screen.dart';
import '../../features/admin/screens/admin_map_screen.dart';
import '../../features/common/screens/global_search_screen.dart';
import '../../features/common/screens/settings_screen.dart';
import '../../features/issues/models/issue.dart';
import '../../features/issues/models/issue_status.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoggedIn = authState.isAuthenticated;
      final role = authState.role;

      // Always allow splash through
      if (path == '/splash') return null;

      // Auth pages — redirect to home if already logged in
      if (path == '/welcome' || path == '/login' || path == '/register') {
        if (!isLoggedIn) return null; // not logged in → show auth pages
        return role == UserRole.admin ? '/admin/dashboard' : '/citizen/home';
      }

      // Protected pages — redirect to welcome if not logged in
      if (!isLoggedIn) return '/welcome';

      // Role-based guards
      if (path.startsWith('/admin') && role != UserRole.admin) {
        return '/citizen/home';
      }
      if (path.startsWith('/citizen') && role != UserRole.citizen) {
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // Auth routes (no shell)
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, s) =>
            _fadePage(state: s, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _slidePage(state: s, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const RegisterScreen()),
      ),

      // ── Common routes (pushed above any shell) ──────────────────────────
      GoRoute(
        path: '/search',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const GlobalSearchScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const SettingsScreen()),
      ),

      // ── Citizen Shell (tab-level screens only) ──────────────────────────
      ShellRoute(
        builder: (context, state, child) => CitizenShell(child: child),
        routes: [
          GoRoute(
            path: '/citizen/home',
            builder: (_, __) => const CitizenHomeScreen(),
          ),
          GoRoute(
            path: '/citizen/my-issues',
            builder: (_, __) => const MyIssuesScreen(),
          ),
        ],
      ),

      // ── Citizen sub-screens (pushed on top of shell, back-swipeable) ────
      GoRoute(
        path: '/citizen/report',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const ReportIssueScreen()),
      ),
      GoRoute(
        path: '/citizen/voice-report',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const VoiceAssistedReportScreen()),
      ),
      GoRoute(
        path: '/citizen/assistant',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const CitizenAssistantScreen()),
      ),
      GoRoute(
        path: '/citizen/leaderboard',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const LeaderboardScreen()),
      ),
      GoRoute(
        path: '/citizen/community',
        builder: (_, __) => const CommunityFeedScreen(),
      ),
      GoRoute(
        path: '/citizen/notifications',
        pageBuilder: (_, s) =>
            _slidePage(state: s, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/citizen/issue/:id',
        builder: (_, s) => IssueDetailsScreen(
          issueId: s.pathParameters['id'] ?? '',
          initialIssue: s.extra is Issue ? s.extra as Issue : null,
        ),
      ),

      // Admin Shell
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
              path: '/admin/dashboard',
              pageBuilder: (_, s) => _instagramStylePage(
                  state: s, child: const AdminDashboardScreen())),
          GoRoute(
              path: '/admin/issues',
              pageBuilder: (_, s) => _instagramStylePage(
                  state: s, child: const AdminIssuesScreen())),
          GoRoute(
            path: '/admin/issue/:id',
            pageBuilder: (_, s) => _instagramStylePage(
              state: s,
              child: AdminIssueDetailsScreen(issueId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
              path: '/admin/analytics',
              pageBuilder: (_, s) => _instagramStylePage(
                  state: s, child: const AdminAnalyticsScreen())),
          GoRoute(
              path: '/admin/map',
              pageBuilder: (_, s) =>
                  _instagramStylePage(state: s, child: const AdminMapScreen())),
        ],
      ),
    ],
  );
});

class _RouteErrorScreen extends StatelessWidget {
  final Exception? error;

  const _RouteErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              const Text(
                'This screen could not be opened.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Please go back and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/citizen/home'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

CustomTransitionPage _fadePage(
    {required GoRouterState state, required Widget child}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 220),
  );
}

CustomTransitionPage _slidePage(
    {required GoRouterState state, required Widget child}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

CustomTransitionPage _instagramStylePage(
    {required GoRouterState state, required Widget child}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      // Slide in from right for forward navigation
      final slideAnimation = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

      // Fade in/out for back navigation
      final fadeAnimation = Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)).animate(animation);

      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
  );
}
