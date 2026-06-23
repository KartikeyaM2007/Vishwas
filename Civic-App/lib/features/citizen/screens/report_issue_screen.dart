// lib/features/citizen/screens/report_issue_screen.dart
// New flow: Category → Location (GPS only) → Photos → [Backend AI classify] → Complaint Details → Submit
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/category_chip.dart';
import '../../issues/models/category.dart';
import '../../issues/models/issue.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/models/location.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/remote_issue_repository.dart';
import '../../auth/controllers/auth_controller.dart';

// ─── Geo-tagged photo ────────────────────────────────────────────────────────
class _GeoPhoto {
  final String path;
  final double? lat;
  final double? lng;
  _GeoPhoto({required this.path, this.lat, this.lng});

  String get geoTag {
    if (lat == null || lng == null) return 'Location unavailable';
    return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});
  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  // Steps: 0=Category, 1=Location, 2=Photos, 3=ComplaintDetails
  int _step = 0;

  // Step 0 – Category
  IssueCategory? _selectedCategory;

  // Step 1 – Location (GPS only)
  bool _locating = false;
  double? _currentLat;
  double? _currentLng;
  String? _detectedAddress; // reverse‑geocoded or coordinate string

  // Step 2 – Photos
  final List<_GeoPhoto> _photos = [];
  bool _isCapturing = false;

  // Classification (between step 2 and 3)
  bool _classifying = false;
  ClassificationResult? _classificationResult;

  // Step 3 – Complaint details (pre‑filled by LLM, user can edit)
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  final _steps = ['Category', 'Location', 'Photos', 'Details'];

  // ── Validation per step ──────────────────────────────────────────────────
  bool get _canProceed {
    switch (_step) {
      case 0:
        return _selectedCategory != null;
      case 1:
        return _currentLat != null && _currentLng != null;
      case 2:
        // User must have at least one photo AND classification must have passed.
        // "Classify & Continue" button handles transition; just need ≥1 photo here.
        return _photos.isNotEmpty;
      case 3:
        return _descCtrl.text.trim().length >= 10;
      default:
        return false;
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────
  void _nextStep() {
    if (_step == 2) {
      // Photo step → classify first, then advance to details
      _classifyAndProceed();
    } else if (_step == _steps.length - 1) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  // ── GPS ──────────────────────────────────────────────────────────────────
  Future<Position?> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _locating = true);
    final pos = await _getLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _detectedAddress =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect location. Please enable GPS and try again.'),
          ),
        );
      }
    });
  }

  // ── Camera capture (camera only, with geo-tag) ───────────────────────────
  Future<void> _capturePhoto() async {
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    final camPerm = await Permission.camera.request();
    if (!camPerm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
      }
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final pos = await _getLocation();
      setState(() {
        _photos.add(_GeoPhoto(
          path: picked.path,
          lat: pos?.latitude ?? _currentLat,
          lng: pos?.longitude ?? _currentLng,
        ));
        _isCapturing = false;
        // Reset any previous classification when a new photo is added
        _classificationResult = null;
      });
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  // ── Backend: Classify image, then advance to details ────────────────────
  Future<void> _classifyAndProceed() async {
    if (_photos.isEmpty || _classifying) return;

    if (_currentLat == null || _currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is required. Go back and detect your location.')),
      );
      return;
    }

    setState(() => _classifying = true);

    try {
      final userState = ref.read(authControllerProvider);
      final remoteRepo = ref.read(remoteIssueRepositoryProvider);
      final result = await remoteRepo.classifyImage(
        imageFile: File(_photos.first.path),
        latitude: _currentLat!,
        longitude: _currentLng!,
        userName: userState.user?.name,
        issueType: _selectedCategory?.id,
      );

      if (!mounted) return;

      if (!result.isValid) {
        setState(() => _classifying = false);
        _showRejectionDialog(result.message);
        return;
      }

      // Pre-fill complaint details from LLM
      _descCtrl.text = result.description;

      setState(() {
        _classificationResult = result;
        _classifying = false;
        _step = 3; // Advance to complaint details
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _classifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Classification failed: $e')),
      );
    }
  }

  void _showRejectionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 48),
        title: const Text('Not a Valid Complaint'),
        content: Text(
          message.isNotEmpty
              ? message
              : 'The image you captured does not appear to show a real civic issue. Please try again with a clearer photo.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ── Final submission ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_submitting) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture at least one photo.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final remoteRepo = ref.read(remoteIssueRepositoryProvider);

    try {
      final result = await remoteRepo.submitComplaint(
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;
      ref.invalidate(allIssuesProvider);
      ref.invalidate(myIssuesProvider);
      setState(() => _submitting = false);

      if (result.isRejected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _SuccessSheet(
          complaintNumber: result.complaintNumber,
          onDone: () {
            Navigator.pop(ctx);
            context.go('/citizen/my-issues');
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step > 0) {
              setState(() {
                _step--;
                // If going back from details, clear classification
                if (_step == 2) _classificationResult = null;
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // ── Step Indicator ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: i ~/ 2 < _step
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  );
                }
                final idx = i ~/ 2;
                final done = idx < _step;
                final active = idx == _step;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done || active
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Center(
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _steps[idx],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // ── Step Content ────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildStep(context),
              ),
            ),
          ),

          // ── Bottom Actions ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _step--;
                        if (_step == 2) _classificationResult = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (_canProceed && !_submitting && !_classifying) ? _nextStep : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 48),
                    ),
                    child: _classifying
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('Verifying Image...'),
                            ],
                          )
                        : _submitting
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _buttonLabel {
    switch (_step) {
      case 2:
        return 'Continue';
      case 3:
        return 'Submit Complaint';
      default:
        return 'Continue';
    }
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _CategoryStep(
          selected: _selectedCategory,
          onSelect: (c) => setState(() => _selectedCategory = c),
        );
      case 1:
        return _LocationStep(
          currentLat: _currentLat,
          currentLng: _currentLng,
          detectedAddress: _detectedAddress,
          locating: _locating,
          onDetect: _detectLocation,
        );
      case 2:
        return _PhotoStep(
          photos: _photos,
          isCapturing: _isCapturing,
          onCapture: _capturePhoto,
          onRemove: (i) => setState(() {
            _photos.removeAt(i);
            _classificationResult = null;
          }),
        );
      case 3:
        return _DetailsStep(
          descCtrl: _descCtrl,
          onChanged: () => setState(() {}),
        );
      default:
        return const SizedBox();
    }
  }
}

// ─── Step 0: Category ────────────────────────────────────────────────────────
class _CategoryStep extends StatelessWidget {
  final IssueCategory? selected;
  final void Function(IssueCategory) onSelect;
  const _CategoryStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Category',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('What type of issue are you reporting?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: IssueCategories.all.length,
          itemBuilder: (_, i) {
            final cat = IssueCategories.all[i];
            return CategoryGridTile(
              category: cat,
              selected: selected?.id == cat.id,
              onTap: () => onSelect(cat),
            );
          },
        ),
      ],
    );
  }
}

// ─── Step 1: Location (GPS Only, No Manual Entry) ────────────────────────────
class _LocationStep extends StatelessWidget {
  final double? currentLat;
  final double? currentLng;
  final String? detectedAddress;
  final bool locating;
  final VoidCallback onDetect;

  const _LocationStep({
    required this.currentLat,
    required this.currentLng,
    required this.detectedAddress,
    required this.locating,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasGps = currentLat != null && currentLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Your current GPS location will be used to pinpoint the issue.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // GPS Status Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hasGps
                ? Colors.green.withValues(alpha: 0.08)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasGps
                  ? Colors.green.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: hasGps
                      ? Colors.green.withValues(alpha: 0.12)
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasGps ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                  color: hasGps ? Colors.green : scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hasGps ? 'Location Detected ✓' : 'Location Not Detected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: hasGps ? Colors.green : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasGps
                    ? detectedAddress ?? 'Coordinates captured'
                    : 'Tap the button below to detect your current GPS location',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (hasGps) ...[
                const SizedBox(height: 6),
                Text(
                  '${currentLat!.toStringAsFixed(6)}, ${currentLng!.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: locating ? null : onDetect,
            icon: locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location_rounded),
            label: Text(locating ? 'Detecting…' : hasGps ? 'Re-detect Location' : 'Detect My Location'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Info note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only your current GPS location is supported. Manual entry has been removed to ensure accurate complaint filing.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Photo Evidence (Camera Only) ────────────────────────────────────
class _PhotoStep extends StatelessWidget {
  final List<_GeoPhoto> photos;
  final bool isCapturing;
  final VoidCallback onCapture;
  final void Function(int) onRemove;

  const _PhotoStep({
    required this.photos,
    required this.isCapturing,
    required this.onCapture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo Evidence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Take a live photo of the issue.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // Capture button
        if (photos.length < 3)
          GestureDetector(
            onTap: isCapturing ? null : onCapture,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: isCapturing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 40, color: scheme.primary),
                        const SizedBox(height: 8),
                        Text('Tap to take live photo',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                        const SizedBox(height: 2),
                        Text('Camera only · Auto geo-tagged',
                            style: TextStyle(
                              color: scheme.primary.withValues(alpha: 0.6),
                              fontSize: 11,
                            )),
                      ],
                    ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text('Maximum 3 photos captured', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),

        if (photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${photos.length} Photo${photos.length > 1 ? 's' : ''} Captured',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...photos.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Image.file(
                          File(p.path),
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 160,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_rounded,
                                color: scheme.onSurfaceVariant, size: 40),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => onRemove(idx),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('Photo ${idx + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    // Geo-tag bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.green.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 14,
                              color: p.lat != null ? Colors.green : scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.lat != null ? 'Geo-tagged: ${p.geoTag}' : 'Location not available',
                              style: TextStyle(
                                fontSize: 11,
                                color: p.lat != null ? Colors.green : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // AI verification banner removed
        ],
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController descCtrl;
  final VoidCallback onChanged;

  const _DetailsStep({
    required this.descCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Complaint Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Please review and edit the details before submitting.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TextFormField(
          controller: descCtrl,
          onChanged: (_) => onChanged(),
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText: 'Describe the issue in detail.',
            alignLabelWithHint: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        Text(
          'You can modify the AI-generated text above before submitting.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Success Bottom Sheet ─────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final String? complaintNumber;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.complaintNumber,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Complaint Submitted!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (complaintNumber != null) ...[
            const SizedBox(height: 6),
            Text('Complaint #$complaintNumber',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary)),
          ],
          const SizedBox(height: 8),
          Text(
            'Your complaint has been filed and is being reviewed by the authorities.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(0, 48)),
              child: const Text('View My Complaints'),
            ),
          ),
        ],
      ),
    );
  }
}
