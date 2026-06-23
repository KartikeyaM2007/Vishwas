// lib/features/auth/screens/welcome_screen.dart
// Beautiful landing screen shown on first launch / after logout
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.85),
                  scheme.primaryContainer,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),

          // Background city pattern
          Positioned.fill(
            child: CustomPaint(painter: _CityPatternPainter()),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.07),

                      // Logo icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.location_city_rounded,
                          size: 56,
                          color: scheme.primary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'CityPulse',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Citizen Issue Portal',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),

                      SizedBox(height: size.height * 0.06),

                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: const [
                          _FeaturePill(Icons.report_problem_rounded, 'Report Issues'),
                          _FeaturePill(Icons.track_changes_rounded, 'Track Status'),
                          _FeaturePill(Icons.location_on_rounded, 'Geo-Tagged'),
                          _FeaturePill(Icons.camera_alt_rounded, 'Photo Evidence'),
                        ],
                      ),

                      const Spacer(),

                      // Buttons
                      _AuthButton(
                        label: 'Create Account',
                        icon: Icons.person_add_rounded,
                        filled: true,
                        onTap: () => context.push('/register'),
                      ),
                      const SizedBox(height: 14),
                      _AuthButton(
                        label: 'Sign In',
                        icon: Icons.login_rounded,
                        filled: false,
                        onTap: () => context.push('/login'),
                      ),

                      const SizedBox(height: 36),

                      Text(
                        'Powered by citizens, for citizens',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _AuthButton({required this.label, required this.icon, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _CityPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Simple building silhouettes at bottom
    final buildingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final buildings = [
      Rect.fromLTWH(0, size.height * 0.6, 50, size.height * 0.4),
      Rect.fromLTWH(55, size.height * 0.65, 35, size.height * 0.35),
      Rect.fromLTWH(95, size.height * 0.55, 60, size.height * 0.45),
      Rect.fromLTWH(160, size.height * 0.7, 40, size.height * 0.3),
      Rect.fromLTWH(205, size.height * 0.6, 70, size.height * 0.4),
      Rect.fromLTWH(280, size.height * 0.72, 45, size.height * 0.28),
      Rect.fromLTWH(330, size.height * 0.58, 50, size.height * 0.42),
      Rect.fromLTWH(width(size, 0.75), size.height * 0.68, 40, size.height * 0.32),
      Rect.fromLTWH(width(size, 0.85), size.height * 0.62, 60, size.height * 0.38),
    ];

    for (final b in buildings) {
      canvas.drawRect(b, buildingPaint);
    }

    // Grid
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double width(Size s, double fraction) => s.width * fraction;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
