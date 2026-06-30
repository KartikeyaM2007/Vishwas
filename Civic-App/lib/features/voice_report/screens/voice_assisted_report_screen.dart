import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/citizen_identity_service.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/remote_issue_repository.dart';

enum VoiceReportStage {
  idle,
  listening,
  transcriptReady,
  extractingIssue,
  gettingLocation,
  waitingForProof,
  validatingProof,
  submitting,
  success,
  validationFailed,
  error,
}

class VoiceAssistedReportScreen extends ConsumerStatefulWidget {
  const VoiceAssistedReportScreen({super.key});

  @override
  ConsumerState<VoiceAssistedReportScreen> createState() =>
      _VoiceAssistedReportScreenState();
}

class _VoiceAssistedReportScreenState
    extends ConsumerState<VoiceAssistedReportScreen> {
  final _speech = stt.SpeechToText();
  final _textController = TextEditingController();
  VoiceReportStage _stage = VoiceReportStage.idle;
  String _transcript = '';
  String? _error;
  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  VoicePrepareResult? _prepared;
  File? _proofFile;
  String? _mediaType;
  EvidenceValidationResult? _validation;
  SubmitComplaintResult? _submitResult;

  bool get _busy =>
      _stage == VoiceReportStage.listening ||
      _stage == VoiceReportStage.extractingIssue ||
      _stage == VoiceReportStage.gettingLocation ||
      _stage == VoiceReportStage.validatingProof ||
      _stage == VoiceReportStage.submitting;

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceReport() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _setError('Microphone permission is required.');
      return;
    }

    final available = await _speech.initialize(
      onError: (error) => _setError(error.errorMsg),
      onStatus: (status) {
        if (status == 'done' &&
            mounted &&
            _stage == VoiceReportStage.listening) {
          setState(() => _stage = VoiceReportStage.transcriptReady);
        }
      },
    );
    if (!available) {
      _setError('Speech recognition is not available on this phone.');
      return;
    }

    setState(() {
      _stage = VoiceReportStage.listening;
      _error = null;
      _transcript = '';
      _textController.clear();
      _prepared = null;
      _proofFile = null;
      _validation = null;
      _submitResult = null;
    });

    await _speech.listen(
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        setState(() {
          _transcript = result.recognizedWords;
          _textController.text = _transcript;
        });
      },
    );
  }

  Future<void> _useTypedText() async {
    final value = _textController.text.trim();
    if (value.length < 5) {
      _setError('Tell me the civic issue you see.');
      return;
    }
    setState(() {
      _transcript = value;
      _stage = VoiceReportStage.transcriptReady;
      _error = null;
    });
    await _prepareReport();
  }

  Future<void> _prepareReport() async {
    final transcript = _textController.text.trim().isNotEmpty
        ? _textController.text.trim()
        : _transcript.trim();
    if (transcript.length < 5) {
      _setError('Tell me the civic issue you see.');
      return;
    }

    await _speech.stop();
    setState(() {
      _stage = VoiceReportStage.gettingLocation;
      _error = null;
      _transcript = transcript;
    });

    final position = await _getLocation();
    if (position == null) {
      _setError('Could not capture location. Enable GPS and try again.');
      return;
    }

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _accuracyMeters = position.accuracy;
      _stage = VoiceReportStage.extractingIssue;
    });

    try {
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      debugPrint(
          'Submitting report for citizen_id: ${maskCitizenId(citizenId)}');
      final prepared = await repo.prepareVoiceReport(
        transcript: transcript,
        latitude: position.latitude,
        longitude: position.longitude,
        username: citizenId,
      );
      if (!mounted) return;
      setState(() {
        _prepared = prepared;
        _stage = VoiceReportStage.waitingForProof;
      });
    } catch (e) {
      _setError('Could not extract issue details: $e');
    }
  }

  Future<Position?> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _capturePhoto() async {
    await _captureProof(isVideo: false);
  }

  Future<void> _recordVideo() async {
    await _captureProof(isVideo: true);
  }

  Future<void> _captureProof({required bool isVideo}) async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      _setError('Camera permission is required.');
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? picked = isVideo
          ? await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(seconds: 20),
            )
          : await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 82,
              maxWidth: 1280,
              maxHeight: 1280,
            );
      if (picked == null) return;

      setState(() {
        _proofFile = File(picked.path);
        _mediaType = isVideo ? 'video' : 'image';
        _validation = null;
      });
      await _validateProof();
    } catch (e) {
      _setError('Could not capture proof: $e');
    }
  }

  Future<void> _validateProof() async {
    if (_proofFile == null || _prepared == null) return;
    if (_latitude == null || _longitude == null) {
      _setError(
          'Current GPS is required before proof validation. Refresh location and try again.');
      return;
    }
    setState(() {
      _stage = VoiceReportStage.validatingProof;
      _error = null;
    });

    try {
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      final result = await repo.validateEvidence(
        file: _proofFile!,
        mediaType: _mediaType ?? 'image',
        claimedIssueType: _prepared!.detectedCategory,
        transcript: _transcript,
        latitude: _latitude!,
        longitude: _longitude!,
        username: citizenId,
      );
      if (!mounted) return;
      setState(() {
        _validation = result;
        _stage = result.success
            ? VoiceReportStage.submitting
            : VoiceReportStage.validationFailed;
      });
      if (result.success) {
        await _submitValidatedReport();
      }
    } catch (e) {
      _setError('Proof validation failed: $e');
    }
  }

  Future<void> _submitValidatedReport() async {
    if (_prepared == null || _proofFile == null) return;
    if (_latitude == null || _longitude == null) {
      _setError(
          'Current GPS is required before report submission. Refresh location and try again.');
      return;
    }
    setState(() => _stage = VoiceReportStage.submitting);
    try {
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      final result = await repo.submitMobileReport(
        file: _proofFile!,
        mediaType: _mediaType ?? 'image',
        issueType: _prepared!.detectedCategory,
        description: _prepared!.cleanSummary,
        latitude: _latitude!,
        longitude: _longitude!,
        username: citizenId,
        validation: _validation?.validation ?? const {},
      );
      if (!mounted) return;
      ref.invalidate(allIssuesProvider);
      ref.invalidate(myIssuesProvider);
      setState(() {
        _submitResult = result;
        _stage = VoiceReportStage.success;
      });
    } catch (e) {
      _setError('Could not submit report: $e');
    }
  }

  Future<void> _submitVideoForManualReview() async {
    if (_mediaType != 'video' || _proofFile == null || _prepared == null) {
      context.push('/citizen/report');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _setError(
          'Current GPS is required before manual review submission. Refresh location and try again.');
      return;
    }
    final validation = Map<String, dynamic>.from(_validation?.validation ?? {});
    validation['recommendation'] = 'manual_review';
    validation['evidence_valid'] = false;

    setState(() => _stage = VoiceReportStage.submitting);
    try {
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      final result = await repo.submitMobileReport(
        file: _proofFile!,
        mediaType: 'video',
        issueType: _prepared!.detectedCategory,
        description: _prepared!.cleanSummary,
        latitude: _latitude!,
        longitude: _longitude!,
        username: citizenId,
        validation: validation,
      );
      if (!mounted) return;
      ref.invalidate(allIssuesProvider);
      ref.invalidate(myIssuesProvider);
      setState(() {
        _submitResult = result;
        _stage = VoiceReportStage.success;
      });
    } catch (e) {
      _setError('Could not submit for manual review: $e');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _stage = VoiceReportStage.error;
    });
  }

  void _resetProof() {
    setState(() {
      _proofFile = null;
      _mediaType = null;
      _validation = null;
      _stage = VoiceReportStage.waitingForProof;
    });
  }

  void _resetAll() {
    setState(() {
      _stage = VoiceReportStage.idle;
      _transcript = '';
      _textController.clear();
      _error = null;
      _latitude = null;
      _longitude = null;
      _accuracyMeters = null;
      _prepared = null;
      _proofFile = null;
      _mediaType = null;
      _validation = null;
      _submitResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assisted Report'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _StageBanner(stage: _stage),
          const SizedBox(height: 16),
          Text(
            'Tell me the civic issue you see.',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 5,
            enabled: !_busy,
            decoration: const InputDecoration(
              hintText: 'Example: There is a pothole on this road.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _transcript = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _startVoiceReport,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(_stage == VoiceReportStage.listening
                      ? 'Listening...'
                      : 'Start Voice Report'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _busy ? null : _useTypedText,
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Use text',
              ),
            ],
          ),
          if (_prepared != null) ...[
            const SizedBox(height: 18),
            _PreparedCard(
              prepared: _prepared!,
              latitude: _latitude,
              longitude: _longitude,
              accuracyMeters: _accuracyMeters,
            ),
          ],
          if (_stage == VoiceReportStage.waitingForProof ||
              _stage == VoiceReportStage.validationFailed) ...[
            const SizedBox(height: 18),
            Text(
              'Please take a photo or record a short video as proof.',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _capturePhoto,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Take Photo Proof'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _recordVideo,
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Record Video Proof'),
                  ),
                ),
              ],
            ),
          ],
          if (_proofFile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _mediaType == 'video'
                        ? Icons.video_file_rounded
                        : Icons.image_rounded,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _mediaType == 'video'
                          ? 'Video proof captured'
                          : 'Photo proof captured',
                    ),
                  ),
                  TextButton(
                      onPressed: _busy ? null : _resetProof,
                      child: const Text('Retake')),
                ],
              ),
            ),
          ],
          if (_stage == VoiceReportStage.validationFailed) ...[
            const SizedBox(height: 16),
            _ValidationFailedCard(
              message: _validation?.message ??
                  'Proof does not match the issue. Please retake or fill manually.',
              validation: _validation?.validation ?? const {},
              isVideo: _mediaType == 'video',
              onRetake: _resetProof,
              onManual: _mediaType == 'video'
                  ? _submitVideoForManualReview
                  : () => context.push('/citizen/report'),
            ),
          ],
          if (_stage == VoiceReportStage.success) ...[
            const SizedBox(height: 18),
            _SuccessCard(
              complaintNumber: _submitResult?.complaintNumber,
              onViewMyIssues: () => context.go('/citizen/my-issues'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _resetAll,
              child: const Text('Retake Voice'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  final VoiceReportStage stage;
  const _StageBanner({required this.stage});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, text) = switch (stage) {
      VoiceReportStage.idle => (
          Icons.auto_awesome_rounded,
          'Ready to help file a report.'
        ),
      VoiceReportStage.listening => (Icons.hearing_rounded, 'Listening...'),
      VoiceReportStage.transcriptReady => (
          Icons.notes_rounded,
          'Transcript ready.'
        ),
      VoiceReportStage.extractingIssue => (
          Icons.psychology_rounded,
          'Extracting issue details...'
        ),
      VoiceReportStage.gettingLocation => (
          Icons.my_location_rounded,
          'Getting location...'
        ),
      VoiceReportStage.waitingForProof => (
          Icons.camera_alt_rounded,
          'Location captured. Waiting for proof.'
        ),
      VoiceReportStage.validatingProof => (
          Icons.verified_rounded,
          'Validating proof...'
        ),
      VoiceReportStage.submitting => (
          Icons.cloud_upload_rounded,
          'Proof validated. Submitting report...'
        ),
      VoiceReportStage.success => (
          Icons.check_circle_rounded,
          'Complaint submitted.'
        ),
      VoiceReportStage.validationFailed => (
          Icons.warning_rounded,
          'Proof does not match the issue.'
        ),
      VoiceReportStage.error => (
          Icons.error_rounded,
          'Something needs attention.'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparedCard extends StatelessWidget {
  final VoicePrepareResult prepared;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  const _PreparedCard({
    required this.prepared,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  Future<void> _openMaps() async {
    if (latitude == null || longitude == null) return;
    final uri = Uri.parse('https://www.google.com/maps?q=$latitude,$longitude');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Detected issue: ${prepared.detectedCategory.replaceAll('_', ' ')}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(prepared.cleanSummary),
          const SizedBox(height: 10),
          Text('Department: ${prepared.department}'),
          Text(
              'Urgency: ${prepared.urgencyLabel} (${prepared.urgencyScore}/10)'),
          if (latitude != null && longitude != null) ...[
            Text('Latitude: ${latitude!.toStringAsFixed(6)}'),
            Text('Longitude: ${longitude!.toStringAsFixed(6)}'),
            if (accuracyMeters != null)
              Text('Accuracy: ${accuracyMeters!.toStringAsFixed(1)} m'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            prepared.proofInstruction,
            style:
                TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ValidationFailedCard extends StatelessWidget {
  final String message;
  final Map<String, dynamic> validation;
  final bool isVideo;
  final VoidCallback onRetake;
  final VoidCallback onManual;

  const _ValidationFailedCard({
    required this.message,
    required this.validation,
    required this.isVideo,
    required this.onRetake,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This media does not clearly show the reported issue. Please retake proof or switch to manual submission.',
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(message),
          if (validation.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ValidationDetail(
              label: 'Provider',
              value: validation['provider']?.toString(),
            ),
            _ValidationDetail(
              label: 'Visible issue',
              value: validation['visible_issue']?.toString(),
            ),
            _ValidationDetail(
              label: 'Detected issue type',
              value: validation['detected_issue_type']?.toString(),
            ),
            _ValidationDetail(
              label: 'Confidence',
              value: validation['confidence'] == null
                  ? null
                  : validation['confidence'].toString(),
            ),
            _ValidationDetail(
              label: 'Recommendation',
              value: validation['recommendation']?.toString(),
            ),
            _ValidationDetail(
              label: 'Reason',
              value: validation['mismatch_reason']?.toString(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onRetake,
                  child: const Text('Retake Proof'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onManual,
                  child: Text(isVideo ? 'Manual Review' : 'Submit Manually'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValidationDetail extends StatelessWidget {
  final String label;
  final String? value;

  const _ValidationDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurface),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String? complaintNumber;
  final VoidCallback onViewMyIssues;

  const _SuccessCard({
    required this.complaintNumber,
    required this.onViewMyIssues,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
        const SizedBox(height: 10),
        Text(
          complaintNumber == null
              ? 'Report submitted'
              : 'Report #$complaintNumber submitted',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onViewMyIssues,
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('View My Issues'),
        ),
      ],
    );
  }
}
