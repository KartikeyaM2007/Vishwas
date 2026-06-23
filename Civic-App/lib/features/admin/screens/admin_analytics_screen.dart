// lib/features/admin/screens/admin_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/models/category.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(issueRepositoryProvider);
    final byCat = repo.getIssueCountByCategory();
    final byWard = repo.getIssueCountByWard();
    final trend = repo.getIssuesTrend(14);
    final scheme = Theme.of(context).colorScheme;

    final catEntries = IssueCategories.all
        .where((c) => (byCat[c.id] ?? 0) > 0)
        .toList();

    final wardEntries = (byWard.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();

    final maxCat = catEntries.isEmpty ? 1.0 : catEntries.map((c) => (byCat[c.id] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
    final maxWard = wardEntries.isEmpty ? 1.0 : wardEntries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Issue trends and distribution', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),

          // Issues over time — Line chart
          _ChartCard(
            title: 'Issues Over Time',
            subtitle: 'Last 14 days',
            icon: Icons.trending_up_rounded,
            color: scheme.primary,
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (v) => FlLine(color: scheme.outlineVariant.withOpacity(0.3), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 3,
                        getTitlesWidget: (x, meta) {
                          if (x.toInt() < trend.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(DateFormat('M/d').format(trend[x.toInt()].key), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (y, _) => Text('${y.toInt()}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList(),
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [scheme.primary.withOpacity(0.2), scheme.primary.withOpacity(0)],
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Issues by Category — Bar chart
          _ChartCard(
            title: 'Issues by Category',
            subtitle: 'Distribution across categories',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF7B1FA2),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxCat + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: scheme.outlineVariant.withOpacity(0.3), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (y, _) => Text('${y.toInt()}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (x, _) {
                          final i = x.toInt();
                          if (i < catEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Icon(catEntries[i].icon, size: 14, color: catEntries[i].color),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(catEntries.length, (i) {
                    final cat = catEntries[i];
                    final count = (byCat[cat.id] ?? 0).toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: cat.color,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Issues by Ward — Bar chart
          _ChartCard(
            title: 'Issues by Ward',
            subtitle: 'Top 6 wards with most issues',
            icon: Icons.location_on_rounded,
            color: const Color(0xFF0288D1),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxWard + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(color: scheme.outlineVariant.withOpacity(0.3), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (y, _) => Text('${y.toInt()}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (x, _) {
                          final i = x.toInt();
                          if (i < wardEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('W${wardEntries[i].key}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(wardEntries.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: wardEntries[i].value.toDouble(),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [const Color(0xFF0288D1).withOpacity(0.5), const Color(0xFF0288D1)],
                          ),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
