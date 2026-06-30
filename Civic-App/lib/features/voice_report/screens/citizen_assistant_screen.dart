import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/citizen_identity_service.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/remote_issue_repository.dart';

enum AssistantCallState {
  idle,
  greeting,
  speaking,
  gettingReady,
  listening,
  thinking,
  capturingLocation,
  waitingForProof,
  openingCameraPhoto,
  openingCameraVideo,
  selectingProof,
  verifyingEvidence,
  submitting,
  completed,
  manualReview,
  error,
}

class CitizenAssistantScreen extends ConsumerStatefulWidget {
  const CitizenAssistantScreen({super.key});

  @override
  ConsumerState<CitizenAssistantScreen> createState() =>
      _CitizenAssistantScreenState();
}

class _CitizenAssistantScreenState
    extends ConsumerState<CitizenAssistantScreen> {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _messages = <_ChatMessage>[];
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _typedMessageController = TextEditingController();

  AssistantCallState _state = AssistantCallState.idle;
  AssistantTurnResult? _lastTurn;
  EvidenceValidationResult? _validation;
  SubmitComplaintResult? _submitResult;
  File? _proofFile;
  String _mediaType = 'image';
  String? _proofSource;
  String? _issueType;
  String? _cleanSummary;
  String? _description;
  String _lastUserMessage = '';
  double? _lat;
  double? _lng;
  double? _accuracy;
  late final Future<void> _ttsReady;
  bool _speechInitializationAttempted = false;
  bool _speechAvailable = false;
  bool _listenResultHandled = false;
  bool _speechRetryAvailable = false;
  bool _locationRetryAvailable = false;
  bool _microphonePermissionDenied = false;
  bool _showTypedInput = false;
  String? _speechLocaleId;
  String _partialTranscript = '';

  @override
  void initState() {
    super.initState();
    _ttsReady = _configureTts();
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _scrollController.dispose();
    _typedMessageController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _appendMessage(_ChatMessage message) {
    setState(() => _messages.add(message));
    _scrollToLatest();
  }

  Future<void> _configureTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.48);
  }

  Future<void> _speak(String text) async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    await _ttsReady;
    if (!mounted) return;
    setState(() {
      _state = AssistantCallState.speaking;
      _messages.add(_ChatMessage.assistant(text));
    });
    _scrollToLatest();
    await _tts.speak(text);
  }

  Map<String, dynamic> _knownData() {
    final validation = _validation?.validation ?? const <String, dynamic>{};
    final confidence = validation['confidence'];
    return {
      'issue_type': _issueType,
      'clean_summary': _cleanSummary,
      'description': _description,
      'latitude': _lat,
      'longitude': _lng,
      'accuracy': _accuracy,
      'media_type': _proofFile == null ? null : _mediaType,
      'media_source': _proofSource,
      'media_present': _proofFile != null,
      'validation_status': _validation == null
          ? null
          : (_validation!.success ? 'verified' : 'failed'),
      'validation_confidence': confidence is num ? confidence : null,
      'validation_provider': validation['provider']?.toString(),
      'evidence_valid': validation['evidence_valid'] == true,
      'matches_claimed_issue': validation['matches_claimed_issue'] == true,
      'last_error': _state == AssistantCallState.error
          ? (_messages.isNotEmpty ? _messages.last.text : null)
          : null,
    };
  }

  String _stateForPlanner() {
    return switch (_state) {
      AssistantCallState.idle => 'idle',
      AssistantCallState.greeting => 'greeting',
      AssistantCallState.speaking => 'speaking',
      AssistantCallState.gettingReady => 'getting_ready',
      AssistantCallState.listening => 'listening_for_issue',
      AssistantCallState.thinking => 'confirming_issue',
      AssistantCallState.capturingLocation => 'get_location',
      AssistantCallState.waitingForProof => 'awaiting_proof',
      AssistantCallState.openingCameraPhoto => 'awaiting_proof',
      AssistantCallState.openingCameraVideo => 'awaiting_proof',
      AssistantCallState.selectingProof => 'awaiting_proof',
      AssistantCallState.verifyingEvidence => 'validating_evidence',
      AssistantCallState.submitting => 'submitting_report',
      AssistantCallState.manualReview => 'manual_review',
      AssistantCallState.completed => 'success',
      AssistantCallState.error => 'error',
    };
  }

  Future<void> _startAssistant() async {
    setState(() {
      _messages.clear();
      _lastTurn = null;
      _validation = null;
      _submitResult = null;
      _proofFile = null;
      _mediaType = 'image';
      _proofSource = null;
      _issueType = null;
      _cleanSummary = null;
      _description = null;
      _lastUserMessage = '';
      _lat = null;
      _lng = null;
      _accuracy = null;
      _speechRetryAvailable = false;
      _locationRetryAvailable = false;
      _microphonePermissionDenied = false;
      _showTypedInput = false;
      _partialTranscript = '';
      _state = AssistantCallState.greeting;
    });
    await _callPlanner(
      'Hi, I am your Community Hero assistant. What civic issue would you like to report?',
    );
  }

  Future<void> _callPlanner(String userMessage) async {
    setState(() => _state = AssistantCallState.thinking);
    try {
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      final turn = await repo.assistantTurn(
        citizenId: citizenId,
        userMessage: userMessage,
        currentState: _stateForPlanner(),
        knownData: _knownData(),
      );
      setState(() {
        _lastTurn = turn;
        _issueType = turn.issueType ?? _issueType;
        _cleanSummary = turn.cleanSummary ?? _cleanSummary;
        _description = turn.description ?? _description;
      });
      await _speak(turn.assistantReply);
      await _executeAction(turn.nextAction);
    } catch (e) {
      _fail('Assistant planner failed: $e');
    }
  }

  Future<void> _executeAction(String action) async {
    switch (action) {
      case 'listen':
      case 'ask_clarifying_question':
        await _listen();
        return;
      case 'get_location':
        await _captureLocation();
        return;
      case 'ask_for_proof':
        setState(() => _state = AssistantCallState.waitingForProof);
        return;
      case 'open_camera_photo':
        await _selectProof(video: false, source: ImageSource.camera);
        return;
      case 'open_camera_video':
        await _selectProof(video: true, source: ImageSource.camera);
        return;
      case 'upload_photo':
        await _selectProof(video: false, source: ImageSource.gallery);
        return;
      case 'upload_video':
        await _selectProof(video: true, source: ImageSource.gallery);
        return;
      case 'validate_evidence':
        await _validateProof();
        return;
      case 'submit_report':
        await _submitReport(manualReview: false);
        return;
      case 'manual_review':
        setState(() => _state = AssistantCallState.manualReview);
        return;
      case 'answer_question':
        await _listen();
        return;
      case 'show_my_issues':
        if (mounted) context.go('/citizen/my-issues');
        return;
      case 'end':
        await _tts.stop();
        await _speech.stop();
        setState(() => _state = AssistantCallState.completed);
        return;
      default:
        setState(() => _state = AssistantCallState.waitingForProof);
    }
  }

  Future<void> _listen() async {
    await _tts.stop();
    final ready = await _ensureSpeechReady();
    if (!ready || !mounted) {
      return;
    }

    if (_speech.isListening) {
      await _speech.cancel();
    }
    setState(() {
      _state = AssistantCallState.gettingReady;
      _speechRetryAvailable = false;
      _locationRetryAvailable = false;
      _microphonePermissionDenied = false;
      _partialTranscript = '';
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    _listenResultHandled = false;
    setState(() => _state = AssistantCallState.listening);
    debugPrint('CitizenAssistant STT listen started');
    await _speech.listen(
      onResult: (result) async {
        final transcript = result.recognizedWords.trim();
        if (!mounted || _listenResultHandled) return;
        setState(() => _partialTranscript = transcript);
        if (result.finalResult && transcript.isNotEmpty) {
          await _acceptTranscript(transcript);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _speechLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<bool> _ensureSpeechReady() async {
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
    }
    if (!mic.isGranted) {
      if (!mounted) return false;
      setState(() {
        _state = AssistantCallState.error;
        _microphonePermissionDenied = true;
        _speechRetryAvailable = false;
        _locationRetryAvailable = false;
        _showTypedInput = true;
        _messages.add(_ChatMessage.assistant(
          mic.isPermanentlyDenied
              ? 'Microphone access is disabled. Open Settings to allow it, or type your report instead.'
              : 'Microphone permission is required for voice input. You can allow it and try again, or type instead.',
        ));
      });
      _scrollToLatest();
      return false;
    }

    if (!_speechInitializationAttempted) {
      _speechInitializationAttempted = true;
      _speechAvailable = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      debugPrint(
        'CitizenAssistant STT available=$_speechAvailable',
      );
      if (_speechAvailable) {
        _speechLocaleId = await _selectSpeechLocale();
        debugPrint(
          'CitizenAssistant STT locale=${_speechLocaleId ?? 'system'}',
        );
      }
    }

    if (!_speechAvailable) {
      _showSpeechRetry(
        'Speech recognition is not available on this phone. Please type your report instead.',
        canRetry: false,
      );
      return false;
    }
    return true;
  }

  Future<String?> _selectSpeechLocale() async {
    try {
      final locales = await _speech.locales();
      String normalize(String value) =>
          value.toLowerCase().replaceAll('-', '_');

      for (final preferred in const ['en_in', 'en_us']) {
        for (final locale in locales) {
          if (normalize(locale.localeId) == preferred) {
            return locale.localeId;
          }
        }
      }
      return (await _speech.systemLocale())?.localeId;
    } catch (_) {
      return null;
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('CitizenAssistant STT error=${error.errorMsg}');
    if (!mounted || _listenResultHandled) return;
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      _showSpeechRetry(
        "I couldn't hear that clearly. Please tap Try Again and speak after the listening indicator appears.",
      );
      return;
    }
    _showSpeechRetry(
      'Voice recognition stopped unexpectedly. Please tap Try Again or type your report instead.',
    );
  }

  void _onSpeechStatus(String status) {
    debugPrint('CitizenAssistant STT status=$status');
    if (!mounted ||
        _listenResultHandled ||
        _state != AssistantCallState.listening) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      debugPrint('CitizenAssistant STT listen stopped');
      final transcript = _partialTranscript.trim();
      if (transcript.isNotEmpty) {
        _acceptTranscript(transcript);
      } else {
        _showSpeechRetry(
          "I couldn't hear that clearly. Please tap Try Again and speak after the listening indicator appears.",
        );
      }
    }
  }

  Future<void> _acceptTranscript(String transcript) async {
    if (_listenResultHandled || transcript.trim().isEmpty) return;
    _listenResultHandled = true;
    debugPrint('CitizenAssistant STT listen stopped');
    await _speech.stop();
    if (!mounted) return;
    final cleaned = transcript.trim();
    setState(() {
      _lastUserMessage = cleaned;
      _speechRetryAvailable = false;
      _locationRetryAvailable = false;
      _partialTranscript = '';
      _state = AssistantCallState.thinking;
      _messages.add(_ChatMessage.user(cleaned));
    });
    _scrollToLatest();
    await _callPlanner(cleaned);
  }

  void _showSpeechRetry(String message, {bool canRetry = true}) {
    if (!mounted || _listenResultHandled) return;
    _listenResultHandled = true;
    _speech.cancel();
    setState(() {
      _state = AssistantCallState.error;
      _speechRetryAvailable = canRetry;
      _locationRetryAvailable = false;
      _showTypedInput = true;
      _partialTranscript = '';
      _messages.add(_ChatMessage.assistant(message));
    });
    _scrollToLatest();
  }

  Future<void> _submitTypedMessage() async {
    final text = _typedMessageController.text.trim();
    if (text.isEmpty) return;
    await _tts.stop();
    if (_speech.isListening) {
      await _speech.cancel();
    }
    if (!mounted) return;
    setState(() {
      _listenResultHandled = true;
      _lastUserMessage = text;
      _speechRetryAvailable = false;
      _locationRetryAvailable = false;
      _microphonePermissionDenied = false;
      _showTypedInput = false;
      _partialTranscript = '';
      _state = AssistantCallState.thinking;
      _messages.add(_ChatMessage.user(text));
      _typedMessageController.clear();
    });
    _scrollToLatest();
    await _callPlanner(text);
  }

  Future<void> _captureLocation() async {
    await _speak(
      'I need your location so the right department can find the issue. I will capture it now.',
    );
    setState(() => _state = AssistantCallState.capturingLocation);
    final pos = await _getRealPosition();
    if (pos == null) {
      _fail(
        'I could not capture your location. Please enable location permission or submit later.',
        allowLocationRetry: true,
      );
      return;
    }
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _accuracy = pos.accuracy;
    });
    _appendMessage(_ChatMessage.system(
      'Location captured: Lat ${pos.latitude.toStringAsFixed(6)}, '
      'Lng ${pos.longitude.toStringAsFixed(6)}, '
      'Accuracy ${pos.accuracy.toStringAsFixed(1)} m',
    ));
    await _callPlanner(
      'Location captured with accuracy of ${pos.accuracy.toStringAsFixed(1)} meters.',
    );
  }

  Future<Position?> _getRealPosition() async {
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
  }

  Future<void> _selectProof({
    required bool video,
    required ImageSource source,
  }) async {
    if (_lat == null || _lng == null) {
      await _callPlanner('Proof requested before location was captured.');
      return;
    }
    if (source == ImageSource.camera) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) {
        _fail('Camera permission is required.');
        return;
      }
    }
    setState(() {
      _state = source == ImageSource.gallery
          ? AssistantCallState.selectingProof
          : video
              ? AssistantCallState.openingCameraVideo
              : AssistantCallState.openingCameraPhoto;
    });
    final picked = video
        ? await _picker.pickVideo(
            source: source,
            maxDuration: source == ImageSource.camera
                ? const Duration(seconds: 20)
                : null,
          )
        : await _picker.pickImage(
            source: source,
            imageQuality: 82,
            maxWidth: 1280,
            maxHeight: 1280,
          );
    if (picked == null) {
      setState(() => _state = AssistantCallState.waitingForProof);
      return;
    }
    final fileName =
        picked.path.split(Platform.pathSeparator).isEmpty
            ? picked.name
            : picked.path.split(Platform.pathSeparator).last;
    final replacedExistingProof = _proofFile != null;
    setState(() {
      _proofFile = File(picked.path);
      _mediaType = video ? 'video' : 'image';
      _proofSource = source == ImageSource.camera
          ? (video ? 'camera_video' : 'camera_photo')
          : (video ? 'uploaded_video' : 'uploaded_photo');
      _validation = null;
      _state = AssistantCallState.waitingForProof;
    });
    _appendMessage(_ChatMessage.user(
      replacedExistingProof
          ? 'Proof replaced: $fileName'
          : '${source == ImageSource.gallery ? 'Uploaded' : 'Captured'} '
              '${video ? 'video' : 'photo'} proof: $fileName',
    ));
    _appendMessage(_ChatMessage.assistant(
      video
          ? 'Video proof was added. Video evidence will be submitted for manual verification.'
          : 'Please wait while I verify the proof.',
    ));
  }

  void _replaceProof() {
    setState(() {
      _proofFile = null;
      _proofSource = null;
      _mediaType = 'image';
      _validation = null;
      _state = AssistantCallState.waitingForProof;
    });
  }

  Future<void> _validateProof() async {
    if (_proofFile == null ||
        _issueType == null ||
        _lat == null ||
        _lng == null) {
      _fail('Transcript, real GPS, and proof media are required.');
      return;
    }
    setState(() => _state = AssistantCallState.verifyingEvidence);
    try {
      _appendMessage(_ChatMessage.assistant(
        'Please wait while I verify the proof.',
      ));
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      _validation = await repo.validateEvidence(
        file: _proofFile!,
        mediaType: _mediaType,
        claimedIssueType: _issueType!,
        transcript: _description ?? _cleanSummary ?? _lastUserMessage,
        latitude: _lat!,
        longitude: _lng!,
        username: citizenId,
      );
      _appendMessage(_ChatMessage.system(
        _validation!.success
            ? 'Proof verified. I am submitting your report.'
            : 'This proof could not be auto-verified. You can retake it or submit for manual verification.',
      ));
      await _callPlanner(_validation!.success
          ? 'Evidence validation passed.'
          : 'Evidence validation failed or needs manual review.');
    } catch (e) {
      _fail('Backend unreachable or validation failed: $e');
    }
  }

  Future<void> _submitReport({required bool manualReview}) async {
    if (_issueType == null ||
        _proofFile == null ||
        _lat == null ||
        _lng == null) {
      _fail('Cannot submit without issue, real GPS, and proof.');
      return;
    }
    if (!manualReview) {
      final validation = _validation?.validation ?? const <String, dynamic>{};
      final confidence = validation['confidence'];
      final valid = _validation?.success == true &&
          validation['evidence_valid'] == true &&
          validation['matches_claimed_issue'] == true &&
          confidence is num &&
          confidence >= 0.65;
      if (!valid) {
        await _callPlanner(
            'Auto-submit blocked because validation did not pass.');
        return;
      }
    }
    setState(() => _state = AssistantCallState.submitting);
    try {
      final validation =
          Map<String, dynamic>.from(_validation?.validation ?? const {});
      if (manualReview) {
        validation['recommendation'] = 'manual_review';
        validation['evidence_valid'] = false;
        validation['matches_claimed_issue'] = false;
        validation['validation_status'] = 'manual_review';
        validation['auto_submitted'] = false;
        validation['reward_eligible'] = false;
        validation['manual_review_reason'] = validation['mismatch_reason'] ??
            validation['reason'] ??
            validation['visible_issue'] ??
            'Proof could not be auto-verified.';
      }
      final repo = ref.read(remoteIssueRepositoryProvider);
      final citizenId = await ref.read(citizenIdentityProvider.future);
      _submitResult = await repo.submitMobileReport(
        file: _proofFile!,
        mediaType: _mediaType,
        issueType: _issueType!,
        description: _description ?? _cleanSummary ?? _lastUserMessage,
        latitude: _lat!,
        longitude: _lng!,
        username: citizenId,
        validation: validation,
        source: 'mobile_agentic_assistant_${_proofSource ?? 'proof'}',
      );
      ref.invalidate(allIssuesProvider);
      ref.invalidate(myIssuesProvider);
      ref.invalidate(leaderboardProvider);
      setState(() => _state = manualReview
          ? AssistantCallState.manualReview
          : AssistantCallState.completed);
      await _speak(
        manualReview
            ? 'Your report has been submitted for manual verification. You can track it in My Issues.'
            : 'Your complaint has been raised successfully. You can check it in My Issues.',
      );
    } catch (e) {
      _fail('Could not submit the report: $e');
    }
  }

  Future<void> _openMaps() async {
    if (_lat == null || _lng == null) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps?q=$_lat,$_lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _fail(String message, {bool allowLocationRetry = false}) {
    setState(() {
      _state = AssistantCallState.error;
      _speechRetryAvailable = false;
      _locationRetryAvailable = allowLocationRetry;
      _messages.add(_ChatMessage.assistant(message));
    });
    _scrollToLatest();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isListening = _state == AssistantCallState.listening;

    return Scaffold(
      appBar: AppBar(title: const Text('Citizen Assistant')),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: 24 +
                MediaQuery.viewPaddingOf(context).bottom +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isListening ? 132 : 112,
              height: isListening ? 132 : 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary
                        .withValues(alpha: isListening ? 0.45 : 0.18),
                    blurRadius: isListening ? 36 : 18,
                    spreadRadius: isListening ? 8 : 2,
                  )
                ],
              ),
              child: Icon(
                  isListening ? Icons.mic_rounded : Icons.support_agent_rounded,
                  size: 62,
                  color: scheme.primary),
            ),
            const SizedBox(height: 10),
            Text(_labelForState(_state),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            if (_state == AssistantCallState.gettingReady)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Get ready to speak...'),
              ),
            if (isListening)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _partialTranscript.isEmpty
                      ? 'Speak now...'
                      : _partialTranscript,
                  textAlign: TextAlign.center,
                ),
              ),
            if (_lastTurn != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _DebugPanel(turn: _lastTurn!),
              ),
            if (_messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final message in _messages) _Bubble(message: message),
                  ],
                ),
              ),
            if (_lat != null && _lng != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GpsCard(
                  latitude: _lat!,
                  longitude: _lng!,
                  accuracy: _accuracy,
                  onOpenMaps: _openMaps,
                ),
              ),
            if (_proofFile != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ProofPreview(
                  file: _proofFile!,
                  mediaType: _mediaType,
                  source: _proofSource ?? 'proof',
                ),
              ),
            if (_validation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ValidationDetailsPanel(
                  message: _validation!.message,
                  validation: _validation!.validation,
                ),
              ),
            if (_submitResult != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _ResultCard(result: _submitResult!),
              ),
            if (_showTypedInput)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _typedMessageController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitTypedMessage(),
                        decoration: const InputDecoration(
                          labelText: 'Type instead',
                          hintText: 'There is a pothole on this road',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _submitTypedMessage,
                      icon: const Icon(Icons.send_rounded),
                      tooltip: 'Send typed report',
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (_state == AssistantCallState.idle ||
                      (_state == AssistantCallState.error &&
                          !_speechRetryAvailable &&
                          !_microphonePermissionDenied))
                    FilledButton.icon(
                      onPressed: _startAssistant,
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Start Assistant'),
                    ),
                  if (_speechRetryAvailable)
                    FilledButton.icon(
                      onPressed: _listen,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Try Again'),
                    ),
                  if (_speechRetryAvailable)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showTypedInput = true),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Type Instead'),
                    ),
                  if (_locationRetryAvailable)
                    FilledButton.icon(
                      onPressed: _captureLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Retry Location'),
                    ),
                  if (_locationRetryAvailable)
                    OutlinedButton.icon(
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open Settings'),
                    ),
                  if (_locationRetryAvailable)
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  if (_microphonePermissionDenied)
                    OutlinedButton.icon(
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open Settings'),
                    ),
                  if (_state != AssistantCallState.idle &&
                      _state != AssistantCallState.completed &&
                      !_showTypedInput)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showTypedInput = true),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Type Instead'),
                    ),
                  if (_state == AssistantCallState.waitingForProof ||
                      _state == AssistantCallState.manualReview) ...[
                    if (_proofFile == null) ...[
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Choose proof',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _selectProof(
                          video: false,
                          source: ImageSource.camera,
                        ),
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('Take Photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectProof(
                          video: true,
                          source: ImageSource.camera,
                        ),
                        icon: const Icon(Icons.videocam_rounded),
                        label: const Text('Record Video'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectProof(
                          video: false,
                          source: ImageSource.gallery,
                        ),
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: const Text('Upload Photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectProof(
                          video: true,
                          source: ImageSource.gallery,
                        ),
                        icon: const Icon(Icons.video_library_rounded),
                        label: const Text('Upload Video'),
                      ),
                    ] else ...[
                      FilledButton.icon(
                        onPressed: _validation == null ? _validateProof : null,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify Proof'),
                      ),
                    ],
                    FilledButton.icon(
                      onPressed: _proofFile == null
                          ? null
                          : () => _submitReport(manualReview: true),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Submit for Manual Verification'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _replaceProof,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Retake / Replace Proof'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Report'),
                    ),
                  ],
                  if (_state == AssistantCallState.completed ||
                      _state == AssistantCallState.manualReview)
                    FilledButton.icon(
                      onPressed: () => context.go('/citizen/my-issues'),
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text('View My Issues'),
                    ),
                  if (_state != AssistantCallState.idle)
                    IconButton.filledTonal(
                      onPressed: () {
                        _tts.stop();
                        _speech.stop();
                        context.pop();
                      },
                      icon: const Icon(Icons.call_end_rounded),
                      tooltip: 'End Assistant',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForState(AssistantCallState state) {
    return switch (state) {
      AssistantCallState.idle => 'Ready',
      AssistantCallState.greeting => 'Speaking',
      AssistantCallState.speaking => 'Speaking',
      AssistantCallState.gettingReady => 'Get ready',
      AssistantCallState.listening => 'Listening now',
      AssistantCallState.thinking => 'Processing',
      AssistantCallState.capturingLocation => 'Capturing Location',
      AssistantCallState.waitingForProof => 'Waiting for Proof',
      AssistantCallState.openingCameraPhoto => 'Opening Camera',
      AssistantCallState.openingCameraVideo => 'Opening Video',
      AssistantCallState.selectingProof => 'Selecting Proof',
      AssistantCallState.verifyingEvidence => 'Verifying Evidence',
      AssistantCallState.submitting => 'Submitting',
      AssistantCallState.completed => 'Completed',
      AssistantCallState.manualReview => 'Manual Review',
      AssistantCallState.error => 'Needs Attention',
    };
  }
}

class _ChatMessage {
  final String text;
  final _ChatRole role;
  final DateTime timestamp;

  _ChatMessage(this.text, this.role) : timestamp = DateTime.now();
  factory _ChatMessage.assistant(String text) =>
      _ChatMessage(text, _ChatRole.assistant);
  factory _ChatMessage.user(String text) => _ChatMessage(text, _ChatRole.user);
  factory _ChatMessage.system(String text) =>
      _ChatMessage(text, _ChatRole.system);
}

enum _ChatRole { assistant, user, system }

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAssistant = message.role == _ChatRole.assistant;
    final isUser = message.role == _ChatRole.user;
    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : isAssistant
              ? Alignment.centerLeft
              : Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.86),
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primary
              : isAssistant
                  ? scheme.surfaceContainerHighest
                  : scheme.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(isAssistant || isUser ? 14 : 10),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? scheme.onPrimary
                    : isAssistant
                        ? scheme.onSurface
                        : scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              TimeOfDay.fromDateTime(message.timestamp).format(context),
              style: TextStyle(
                fontSize: 10,
                color: (isUser ? scheme.onPrimary : scheme.onSurface)
                    .withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final AssistantTurnResult turn;
  const _DebugPanel({required this.turn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: const Text('Debug details'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'next_action: ${turn.nextAction}\n'
              'safety: ${turn.safetyStatus}\n'
              'reason: ${turn.reason}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final VoidCallback onOpenMaps;

  const _GpsCard({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(
        'Lat ${latitude.toStringAsFixed(6)}  Lng ${longitude.toStringAsFixed(6)}',
      ),
      subtitle: accuracy == null
          ? null
          : Text('Accuracy ${accuracy!.toStringAsFixed(1)} m'),
      trailing: IconButton(
        onPressed: onOpenMaps,
        icon: const Icon(Icons.map_rounded),
        tooltip: 'Open in Maps',
      ),
    );
  }
}

class _ProofPreview extends StatelessWidget {
  final File file;
  final String mediaType;
  final String source;

  const _ProofPreview({
    required this.file,
    required this.mediaType,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';
    final fileName =
        file.uri.pathSegments.isEmpty ? 'proof' : file.uri.pathSegments.last;
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 118,
            height: 118,
            child: isVideo
                ? const Center(child: Icon(Icons.videocam_rounded, size: 42))
                : Image.file(file, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mediaType == 'video' ? 'Video proof' : 'Photo proof',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Source: ${source.startsWith('uploaded') ? 'Gallery' : 'Camera'}',
                  ),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationDetailsPanel extends StatelessWidget {
  final String message;
  final Map<String, dynamic> validation;

  const _ValidationDetailsPanel({
    required this.message,
    required this.validation,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = validation['evidence_valid'] == true &&
        validation['matches_claimed_issue'] == true;
    final citizenMessage = success
        ? 'Proof verified. This report can be submitted.'
        : 'AI evidence validation is unavailable or confidence is too low. Submit for manual verification?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            citizenMessage,
            style: TextStyle(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!success) ...[
            const SizedBox(height: 6),
            Text(
              'You can retake the proof, replace it, or send the report to an admin for manual verification. Manual reports do not receive rewards unless approved.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ],
          if (validation.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Validation details',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
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
                  value: validation['confidence']?.toString(),
                ),
                _ValidationDetail(
                  label: 'Recommendation',
                  value: validation['recommendation']?.toString(),
                ),
                _ValidationDetail(
                  label: 'Reason',
                  value: validation['mismatch_reason']?.toString() ??
                      validation['reason']?.toString() ??
                      message,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationDetail extends StatelessWidget {
  final String label;
  final String? value;

  const _ValidationDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SubmitComplaintResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.primaryContainer,
      title: Text(result.message),
      subtitle: Text(
        'Complaint id: ${result.complaintId ?? 'manual review pending'}\n'
        'Validation status: submitted\n'
        'Reward eligibility: only after verified/approved/resolved',
      ),
      trailing: const Icon(Icons.check_circle_rounded),
    );
  }
}
