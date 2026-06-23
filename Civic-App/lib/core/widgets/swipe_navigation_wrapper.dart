// lib/core/widgets/swipe_navigation_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

class SwipeNavigationWrapper extends StatelessWidget {
  final Widget child;
  final bool enableSwipeBack;

  const SwipeNavigationWrapper({
    super.key,
    required this.child,
    this.enableSwipeBack = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableSwipeBack) return child;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // Handle back navigation - only pop if there's a previous route
        if (GoRouter.of(context).canPop()) {
          context.pop();
        }
        // If we can't pop, don't do anything (prevents app exit)
      },
      child: GestureDetector(
        onPanEnd: (details) {
          // Swipe from left edge to go back (Instagram-style)
          if (details.velocity.pixelsPerSecond.dx > 300) {
            // Only navigate back if there's a previous route in the stack
            if (GoRouter.of(context).canPop()) {
              context.pop();
            }
          }
        },
        child: child,
      ),
    );
  }
}

class SwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final double swipeThreshold;
  final double velocityThreshold;

  const SwipeDetector({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onSwipeUp,
    this.onSwipeDown,
    this.swipeThreshold = 50.0,
    this.velocityThreshold = 300.0,
  });

  @override
  State<SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        
        // Horizontal swipes
        if (velocity.dx.abs() > widget.velocityThreshold) {
          if (velocity.dx > 0 && widget.onSwipeRight != null) {
            widget.onSwipeRight!();
          } else if (velocity.dx < 0 && widget.onSwipeLeft != null) {
            widget.onSwipeLeft!();
          }
        }
        
        // Vertical swipes
        if (velocity.dy.abs() > widget.velocityThreshold) {
          if (velocity.dy > 0 && widget.onSwipeDown != null) {
            widget.onSwipeDown!();
          } else if (velocity.dy < 0 && widget.onSwipeUp != null) {
            widget.onSwipeUp!();
          }
        }
      },
      child: widget.child,
    );
  }
}
