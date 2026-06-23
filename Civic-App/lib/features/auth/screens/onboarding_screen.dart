// lib/features/auth/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.report_problem_rounded,
      color: Color(0xFF1565C0),
      title: 'Report Issues Instantly',
      subtitle: 'Spot a pothole, broken streetlight, or water leak? Report it in seconds with just a tap.',
    ),
    _OnboardingSlide(
      icon: Icons.track_changes_rounded,
      color: Color(0xFF0288D1),
      title: 'Track in Real-Time',
      subtitle: 'Follow the status of your reported issues from Open to Resolved — live updates, always.',
    ),
    _OnboardingSlide(
      icon: Icons.handshake_rounded,
      color: Color(0xFF00897B),
      title: 'Build Better Cities Together',
      subtitle: 'Your voice matters. Join thousands of citizens making your city cleaner, safer, and smarter.',
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    if (mounted) context.go('/citizen/home');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final s = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(colors: [
                              s.color.withValues(alpha: 0.15),
                              s.color.withValues(alpha: 0.03),
                            ]),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 80, color: s.color),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? slide.color : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: slide.color,
                    ),
                    child: Text(
                      _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
