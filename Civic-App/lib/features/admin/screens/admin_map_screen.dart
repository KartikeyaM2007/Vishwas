// lib/features/admin/screens/admin_map_screen.dart
// Uses flutter_map + OpenStreetMap for a real interactive map
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/status_pill.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/issue_repository.dart';
import '../../issues/models/issue.dart';
import '../../issues/models/issue_status.dart';

class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});
  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen> {
  IssueStatus? _filterStatus;
  Issue? _selectedIssue;
  final MapController _mapController = MapController();

  // Default center — India center (or user's location if available)
  static const _defaultCenter = LatLng(20.5937, 78.9629);
  static const _defaultZoom = 5.0;
  static const _pinZoom = 15.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final issuesAsync = ref.watch(allIssuesProvider);

    return Stack(
      children: [
        issuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn’t load complaints',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          data: (allIssuesRaw) {
            final allIssues = _filterStatus != null
                ? allIssuesRaw.where((i) => i.status == _filterStatus).toList()
                : allIssuesRaw;

            // Only show issues that have GPS coordinates
            final geoIssues = allIssues.where((i) => i.location.hasCoordinates).toList();
            final noGeoIssues = allIssues.where((i) => !i.location.hasCoordinates).toList();

            return Stack(
              children: [
                Column(
                  children: [
                    // Header + filter
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.map_rounded, color: scheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Issue Map',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${geoIssues.length} on map',
                                  style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                FilterChip(
                                  label: const Text('All'),
                                  selected: _filterStatus == null,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() {
                                    _filterStatus = null;
                                    _selectedIssue = null;
                                  }),
                                ),
                                ...IssueStatus.values.map((s) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FilterChip(
                                    label: Text(s.label),
                                    selected: _filterStatus == s,
                                    showCheckmark: false,
                                    onSelected: (_) => setState(() {
                                      _filterStatus = _filterStatus == s ? null : s;
                                      _selectedIssue = null;
                                    }),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultCenter,
                              initialZoom: _defaultZoom,
                              onTap: (_, __) => setState(() => _selectedIssue = null),
                            ),
                            children: [
                              // OpenStreetMap tile layer
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.citypulse.civic_app',
                                maxZoom: 19,
                              ),

                              // Issue markers
                              MarkerLayer(
                                markers: geoIssues.map((issue) {
                                  final lat = issue.location.latitude!;
                                  final lng = issue.location.longitude!;
                                  final isSelected = _selectedIssue?.id == issue.id;
                                  final color = _statusColor(issue.status);

                                  return Marker(
                                    point: LatLng(lat, lng),
                                    width: isSelected ? 44 : 34,
                                    height: isSelected ? 44 : 34,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedIssue = issue);
                                        _mapController.move(LatLng(lat, lng), _pinZoom);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withValues(alpha: isSelected ? 0.5 : 0.3),
                                              blurRadius: isSelected ? 14 : 6,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          issue.category.icon,
                                          size: isSelected ? 22 : 17,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),

                          // Legend overlay
                          Positioned(
                            top: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: IssueStatus.values.map((s) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10, height: 10,
                                        decoration: BoxDecoration(
                                          color: _statusColor(s),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(s.label, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          ),

                          // No geo-tagged issues notice
                          if (geoIssues.isEmpty && allIssues.isNotEmpty)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_off_rounded, size: 40, color: scheme.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text('No geo-tagged issues',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issues will appear on the map when\ncitizens report with GPS enabled.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (allIssues.isEmpty)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_outlined, size: 40, color: scheme.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text('No issues yet',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issues reported by citizens will\nappear as pins on this map.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Non-geo listed issues bar
                    if (noGeoIssues.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: scheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            Icon(Icons.location_off_rounded, size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${noGeoIssues.length} issue${noGeoIssues.length > 1 ? 's' : ''} without GPS coordinates',
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Selected issue preview
                if (_selectedIssue != null)
                  Positioned(
                    bottom: noGeoIssues.isNotEmpty ? 38 : 0,
                    left: 0,
                    right: 0,
                    child: _IssuePreviewSheet(
                      issue: _selectedIssue!,
                      onClose: () => setState(() => _selectedIssue = null),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Color _statusColor(IssueStatus s) {
    switch (s) {
      case IssueStatus.open: return const Color(0xFFE53935);
      case IssueStatus.inProgress: return const Color(0xFFF57C00);
      case IssueStatus.resolved: return const Color(0xFF2E7D32);
      case IssueStatus.rejected: return const Color(0xFF616161);
    }
  }
}

class _IssuePreviewSheet extends StatelessWidget {
  final Issue issue;
  final VoidCallback onClose;
  const _IssuePreviewSheet({required this.issue, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: issue.category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(issue.category.icon, color: issue.category.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.category.name,
                        style: TextStyle(fontSize: 11, color: issue.category.color, fontWeight: FontWeight.w600)),
                    Text(issue.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            issue.location.hasCoordinates
                                ? issue.location.coordinatesString
                                : issue.location.displayName,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusPill(status: issue.status),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/admin/issue/${issue.id}'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('View', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
