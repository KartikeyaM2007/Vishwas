// lib/core/widgets/skeleton_loader.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A3344) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3D4F66) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class IssueCardSkeleton extends StatelessWidget {
  const IssueCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 32, height: 32, radius: 8),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SkeletonBox(height: 10, radius: 6),
                    const SizedBox(height: 2),
                    const SkeletonBox(height: 14, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const SkeletonBox(width: 60, height: 20, radius: 100),
            ],
          ),
          const SizedBox(height: 6),
          const SkeletonBox(height: 14, radius: 6),
          const SizedBox(height: 6),
          Row(
            children: const [
              SkeletonBox(width: 11, height: 11, radius: 100),
              SizedBox(width: 3),
              Expanded(child: SkeletonBox(height: 10, radius: 6)),
              SizedBox(width: 6),
              SkeletonBox(width: 11, height: 11, radius: 100),
              SizedBox(width: 3),
              SkeletonBox(width: 40, height: 10, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (context, index) => const IssueCardSkeleton(),
    );
  }
}

class KpiCardSkeleton extends StatelessWidget {
  const KpiCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 28, height: 28, radius: 6),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Flexible(
                  child: SkeletonBox(height: 20, radius: 6),
                ),
                const SizedBox(height: 1),
                const Flexible(
                  child: SkeletonBox(width: 80, height: 9, radius: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
