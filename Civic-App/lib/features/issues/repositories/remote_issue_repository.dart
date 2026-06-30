// lib/features/issues/repositories/remote_issue_repository.dart
// Connects CityPulse Flutter app to the Django REST API backend.
// Authentication token is automatically attached via ApiService.

import 'dart:io';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../models/complaint_comment.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';
import '../models/category.dart';
import '../models/location.dart';
import 'issue_repository.dart';

// ── Image Classification Result (Step 1: Validation) ────────────────────────
class ClassificationResult {
  final bool isValid;
  final String description;
  final String message;

  const ClassificationResult({
    required this.isValid,
    required this.description,
    required this.message,
  });
}

// ── Final Submission Result (Step 2: Save to DB) ─────────────────────────────
class SubmitComplaintResult {
  final bool isDuplicate;
  final bool isRejected;
  final String? complaintId;
  final String? complaintNumber;
  final String message;

  const SubmitComplaintResult({
    required this.isDuplicate,
    required this.isRejected,
    required this.complaintId,
    required this.complaintNumber,
    required this.message,
  });
}

class VoicePrepareResult {
  final String detectedCategory;
  final String cleanSummary;
  final int urgencyScore;
  final String urgencyLabel;
  final String department;
  final String proofInstruction;
  final Map<String, dynamic> aiMetadata;

  const VoicePrepareResult({
    required this.detectedCategory,
    required this.cleanSummary,
    required this.urgencyScore,
    required this.urgencyLabel,
    required this.department,
    required this.proofInstruction,
    required this.aiMetadata,
  });
}

class EvidenceValidationResult {
  final bool success;
  final bool requiresManualReview;
  final String message;
  final Map<String, dynamic> validation;

  const EvidenceValidationResult({
    required this.success,
    required this.requiresManualReview,
    required this.message,
    required this.validation,
  });
}

class AssistantTurnResult {
  final String assistantReply;
  final String nextAction;
  final String? issueType;
  final String? cleanSummary;
  final String? description;
  final List<String> missingFields;
  final bool requiresUserConfirmation;
  final String safetyStatus;
  final String reason;

  const AssistantTurnResult({
    required this.assistantReply,
    required this.nextAction,
    required this.issueType,
    required this.cleanSummary,
    required this.description,
    required this.missingFields,
    required this.requiresUserConfirmation,
    required this.safetyStatus,
    required this.reason,
  });

  factory AssistantTurnResult.fromJson(Map<String, dynamic> json) {
    return AssistantTurnResult(
      assistantReply: json['assistant_reply']?.toString() ??
          'What civic issue would you like to report?',
      nextAction: json['next_action']?.toString() ?? 'listen',
      issueType: json['issue_type']?.toString() == 'null'
          ? null
          : json['issue_type']?.toString(),
      cleanSummary: json['clean_summary']?.toString() == 'null'
          ? null
          : json['clean_summary']?.toString(),
      description: json['description']?.toString() == 'null'
          ? null
          : json['description']?.toString(),
      missingFields: (json['missing_fields'] as List<dynamic>? ?? const [])
          .map((field) => field.toString())
          .toList(),
      requiresUserConfirmation: json['requires_user_confirmation'] == true,
      safetyStatus: json['safety_status']?.toString() ?? 'needs_more_info',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String username;
  final int points;
  final int authenticReports;
  final int resolvedReports;
  final int manualReviewReports;
  final int rejectedReports;
  final String badge;

  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.points,
    required this.authenticReports,
    required this.resolvedReports,
    required this.manualReviewReports,
    required this.rejectedReports,
    required this.badge,
  });
}

String humanizeCivicValue(String value) {
  final words = value.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String _validationMessageFrom(Map<String, dynamic> data) {
  final validation =
      (data['validation'] as Map?)?.cast<String, dynamic>() ?? {};
  final code = validation['validation_error_code']?.toString();
  if (code == 'GEMINI_API_KEY_INVALID' || code == 'AI_UNAVAILABLE') {
    return 'AI evidence validation is currently unavailable. This report cannot be auto-submitted. Please retake proof or submit for manual review.';
  }
  if (code == 'LOW_CONFIDENCE') {
    return 'AI confidence is too low for auto-submit. Please retake proof or submit manually.';
  }
  if (code == 'UNSUPPORTED_VIDEO_VALIDATION') {
    return 'Video semantic validation is not available. Submit this video for manual review.';
  }
  if (code == 'UNSUPPORTED_IMAGE_TYPE' || code == 'UNSUPPORTED_PROOF_TYPE') {
    return 'Unsupported proof file type. Please upload JPG, PNG, WEBP, or MP4.';
  }
  return data['message']?.toString() ??
      'This proof does not match the reported issue. Please retake photo/video or submit manually.';
}

/// Maps backend issue_type strings to frontend IssueCategory objects.
IssueCategory _categoryFromType(String issueType) {
  switch (issueType) {
    case 'pothole':
      return IssueCategories.road;
    case 'garbage':
      return IssueCategories.garbage;
    case 'water_leakage':
    case 'drain':
      return IssueCategories.water;
    case 'streetlight':
    case 'streetlight_damage':
      return IssueCategories.electricity;
    default:
      return IssueCategories.other;
  }
}

/// Maps backend status strings to frontend IssueStatus enum.
IssueStatus _statusFromValue(String? s) => IssueStatus.fromValue(s ?? '');

/// Converts a raw complaint JSON map (from the list/detail endpoint)
/// into a frontend [Issue] model.
Issue _issueFromJson(Map<String, dynamic> json) {
  final imageUrl = (json['media_url'] ?? json['image_url']) as String?;
  final metadata = (json['ai_metadata'] as Map?)?.cast<String, dynamic>() ?? {};
  final validation =
      (metadata['validation'] as Map?)?.cast<String, dynamic>() ?? {};
  final validationStatus = json['validation_status']?.toString() ??
      metadata['validation_status']?.toString() ??
      (validation['evidence_valid'] == true ? 'verified' : 'unknown');
  final issueType = json['issue_type'] as String? ?? 'issue';
  return Issue(
    id: json['id'].toString(),
    title: humanizeCivicValue(issueType),
    description: json['complaint_desc'] as String? ??
        json['description'] as String? ??
        '',
    category: _categoryFromType(json['issue_type'] as String? ?? ''),
    location: IssueLocation(
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      areaName: 'Detected Location',
      wardNumber: '',
    ),
    status: _statusFromValue(json['status'] as String?),
    createdAt: DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
        DateTime.now(),
    updatedAt: DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
        DateTime.now(),
    reporterId:
        json['citizen_id']?.toString() ?? json['username']?.toString() ?? '',
    reporterName: json['username']?.toString() ?? 'Citizen',
    attachments: imageUrl != null ? [imageUrl] : [],
    upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
    isUrgent: ((json['severity'] as num?)?.toInt() ?? 0) >= 7,
    validationStatus: validationStatus,
    rewardEligible:
        json['reward_eligible'] == true || metadata['reward_eligible'] == true,
    mediaType: json['media_type']?.toString() ??
        metadata['media_type']?.toString() ??
        'image',
    commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
  );
}

class RemoteIssueRepository extends IssueRepository {
  // Temporary storage to hold data between classifyImage and submitComplaint
  File? _tempImage;
  double? _tempLat;
  double? _tempLng;
  String? _tempUserName;
  String? _tempIssueType;

  // ── Step 1: Classify image (AI validation + LLM text generation) ────────────
  Future<ClassificationResult> classifyImage({
    required File imageFile,
    required double latitude,
    required double longitude,
    String? userName,
    String? issueType,
  }) async {
    // Save details temporarily for mock submission
    _tempImage = imageFile;
    _tempLat = latitude;
    _tempLng = longitude;
    _tempUserName = userName;
    _tempIssueType = issueType;

    final response = await ApiService.postMultipart(
      '/upload_details',
      fields: {
        'username': userName ?? '',
        'issue_type': issueType ?? '',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
      filePath: imageFile.path,
      fileField: 'image',
    );

    final data = ApiService.decodeResponse(response) as Map<String, dynamic>;
    final isTrueImage = data['is_true_image'] as bool? ?? false;
    final complaintDescription = data['complaint_description'] as String? ?? '';

    return ClassificationResult(
      isValid: isTrueImage,
      description: complaintDescription,
      message: data['message'] as String? ?? '',
    );
  }

  // ── Step 2: Submit complaint with image (store in DB) ───────────────────────
  Future<SubmitComplaintResult> submitComplaint({
    String description = '',
  }) async {
    if (_tempLat == null || _tempLng == null) {
      throw Exception('Current GPS is required before report submission.');
    }
    // Final submit is a UI confirmation step.
    await Future.delayed(const Duration(milliseconds: 200));

    // MOCK: Add to base IssueRepository so it shows up in "My Issues"
    final newIssue = Issue(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      title: '${(_tempIssueType ?? "Issue").toUpperCase()} Report',
      description: description,
      category: _categoryFromType(_tempIssueType ?? ''),
      location: IssueLocation(
        latitude: _tempLat,
        longitude: _tempLng,
        areaName: 'Detected Location',
        wardNumber: 'Ward 1',
      ),
      status: IssueStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      reporterId: _tempUserName ?? 'mobile_user',
      reporterName: _tempUserName ?? 'Citizen',
      attachments: _tempImage != null ? [_tempImage!.path] : [],
    );
    createIssue(newIssue);

    return const SubmitComplaintResult(
      isDuplicate: false,
      isRejected: false,
      complaintId: null,
      complaintNumber: null,
      message: 'Complaint submitted.',
    );
  }

  // ── Fetch all complaints ───────────────────────────────────────────────────
  Future<List<Issue>> fetchComplaints({
    IssueFilters? filters,
    SortOrder sort = SortOrder.latest,
  }) async {
    final response = await ApiService.get('/complaints');
    final decoded = ApiService.decodeResponse(response);
    if (!ApiService.isSuccess(response)) {
      throw Exception(decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to load complaints from $kBaseUrl.');
    }
    if (decoded is! Map) {
      throw Exception('Unexpected complaints response from $kBaseUrl.');
    }

    final dataList = decoded['data'] as List<dynamic>? ?? [];
    var issues = dataList
        .map((json) => _issueFromJson((json as Map).cast<String, dynamic>()))
        .toList();

    if (filters?.status != null) {
      issues =
          issues.where((issue) => issue.status == filters!.status).toList();
    }
    if (filters?.categoryId != null && filters!.categoryId!.isNotEmpty) {
      issues = issues
          .where((issue) => issue.category.id == filters.categoryId)
          .toList();
    }
    if (filters?.wardNumber != null && filters!.wardNumber!.isNotEmpty) {
      issues = issues
          .where((issue) => issue.location.wardNumber == filters.wardNumber)
          .toList();
    }

    if (sort == SortOrder.latest) {
      issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      issues.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return issues;
  }

  // ── Fetch MY complaints ────────────────────────────────────────────────────
  Future<List<Issue>> fetchMyComplaints(String citizenId) async {
    final issues = await fetchComplaints();
    return issues
        .where((issue) =>
            issue.reporterId == citizenId || issue.reporterName == citizenId)
        .toList();
  }

  Future<Issue?> fetchComplaintById(String id) async {
    try {
      final response = await ApiService.get('/complaints/$id');
      final decoded = ApiService.decodeResponse(response);
      if (!ApiService.isSuccess(response)) return null;
      final data = (decoded as Map<String, dynamic>)['data'];
      if (data is! Map) return null;
      return _issueFromJson(data.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<VoicePrepareResult> prepareVoiceReport({
    required String transcript,
    required double latitude,
    required double longitude,
    required String username,
  }) async {
    final response = await ApiService.post('/mobile/voice-prepare', {
      'transcript': transcript,
      'latitude': latitude,
      'longitude': longitude,
      'username': username,
    });
    final data = ApiService.decodeResponse(response) as Map<String, dynamic>;
    if (!ApiService.isSuccess(response)) {
      throw Exception(data['detail']?.toString() ?? 'Voice prepare failed');
    }
    return VoicePrepareResult(
      detectedCategory: data['detected_category']?.toString() ?? 'other',
      cleanSummary: data['clean_summary']?.toString() ?? transcript,
      urgencyScore: (data['urgency_score'] as num?)?.toInt() ?? 5,
      urgencyLabel: data['urgency_label']?.toString() ?? 'medium',
      department: data['department']?.toString() ?? 'General Civic Team',
      proofInstruction: data['proof_instruction']?.toString() ??
          'Please capture proof of the issue.',
      aiMetadata: (data['ai_metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<AssistantTurnResult> assistantTurn({
    required String citizenId,
    required String userMessage,
    required String currentState,
    required Map<String, dynamic> knownData,
  }) async {
    final response = await ApiService.post('/mobile/assistant-turn', {
      'citizen_id': citizenId,
      'user_message': userMessage,
      'current_state': currentState,
      'known_data': knownData,
    });
    final data = ApiService.decodeResponse(response) as Map<String, dynamic>;
    if (!ApiService.isSuccess(response)) {
      throw Exception(data['detail']?.toString() ?? 'Assistant turn failed');
    }
    return AssistantTurnResult.fromJson(data);
  }

  Future<EvidenceValidationResult> validateEvidence({
    required File file,
    required String mediaType,
    required String claimedIssueType,
    required String transcript,
    required double latitude,
    required double longitude,
    required String username,
  }) async {
    final response = await ApiService.postMultipart(
      '/mobile/validate-evidence',
      fields: {
        'media_type': mediaType,
        'claimed_issue_type': claimedIssueType,
        'transcript': transcript,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'username': username,
      },
      filePath: file.path,
      fileField: 'file',
    );
    final decoded = ApiService.decodeResponse(response);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'message': decoded.toString()};
    final validation =
        (data['validation'] as Map?)?.cast<String, dynamic>() ?? {};
    return EvidenceValidationResult(
      success: ApiService.isSuccess(response) && data['success'] == true,
      requiresManualReview: data['requires_manual_review'] == true,
      message: ApiService.isSuccess(response)
          ? (data['message']?.toString() ?? 'Proof validated.')
          : _validationMessageFrom(data),
      validation: validation,
    );
  }

  Future<SubmitComplaintResult> submitMobileReport({
    required File file,
    required String mediaType,
    required String issueType,
    required String description,
    required double latitude,
    required double longitude,
    required String username,
    required Map<String, dynamic> validation,
    String source = 'mobile_voice',
  }) async {
    final response = await ApiService.postMultipart(
      '/mobile/report-submit',
      fields: {
        'media_type': mediaType,
        'issue_type': issueType,
        'description': description,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'username': username,
        'validation_json': jsonEncode(validation),
        'source': source,
      },
      filePath: file.path,
      fileField: 'file',
    );
    final data = ApiService.decodeResponse(response) as Map<String, dynamic>;
    if (!ApiService.isSuccess(response) || data['success'] != true) {
      throw Exception(data['detail']?.toString() ??
          data['message']?.toString() ??
          'Report submit failed');
    }
    final report = (data['data'] as Map?)?.cast<String, dynamic>() ?? {};
    return SubmitComplaintResult(
      isDuplicate: false,
      isRejected: false,
      complaintId: report['id']?.toString(),
      complaintNumber: report['id']?.toString(),
      message: data['message']?.toString() ?? 'Complaint submitted.',
    );
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final response = await ApiService.get('/mobile/leaderboard');
    final decoded = ApiService.decodeResponse(response);
    if (!ApiService.isSuccess(response)) {
      throw Exception(decoded.toString());
    }
    final rows = decoded as List<dynamic>;
    return rows.map((row) {
      final json = (row as Map).cast<String, dynamic>();
      return LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        username: json['username']?.toString() ?? 'Citizen',
        points: (json['points'] as num?)?.toInt() ?? 0,
        authenticReports: (json['authentic_reports'] as num?)?.toInt() ?? 0,
        resolvedReports: (json['resolved_reports'] as num?)?.toInt() ?? 0,
        manualReviewReports:
            (json['manual_review_reports'] as num?)?.toInt() ?? 0,
        rejectedReports: (json['rejected_reports'] as num?)?.toInt() ?? 0,
        badge: json['badge']?.toString() ?? 'New Reporter',
      );
    }).toList();
  }

  Future<List<ComplaintComment>> fetchComments(
    String complaintId, {
    String sort = 'newest',
  }) async {
    final response = await ApiService.get(
      '/complaints/$complaintId/comments?sort=$sort',
    );
    final decoded = ApiService.decodeResponse(response);
    if (!ApiService.isSuccess(response)) {
      throw Exception(decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to load comments');
    }
    final rows =
        (decoded as Map<String, dynamic>)['data'] as List<dynamic>? ?? const [];
    return rows
        .map((row) =>
            ComplaintComment.fromJson((row as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addComment({
    required String complaintId,
    required String userId,
    required String username,
    required String body,
  }) async {
    final response =
        await ApiService.post('/complaints/$complaintId/comments', {
      'user_id': userId,
      'username': username,
      'user_role': 'citizen',
      'body': body,
      'is_verified_user': true,
    });
    final decoded = ApiService.decodeResponse(response);
    if (!ApiService.isSuccess(response)) {
      throw Exception(decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to add comment');
    }
  }

  Future<void> replyToComment({
    required String complaintId,
    required int commentId,
    required String userId,
    required String username,
    required String body,
  }) async {
    final response = await ApiService.post(
      '/complaints/$complaintId/comments/$commentId/reply',
      {
        'user_id': userId,
        'username': username,
        'user_role': 'citizen',
        'body': body,
        'is_verified_user': true,
      },
    );
    final decoded = ApiService.decodeResponse(response);
    if (!ApiService.isSuccess(response)) {
      throw Exception(decoded is Map && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Unable to add reply');
    }
  }

  // ── Upvote a complaint ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> upvoteComplaint(String complaintId) async {
    // TODO: RESTORE REAL API — MOCK VERSION
    await Future.delayed(const Duration(milliseconds: 300));
    return {'status': 'success', 'upvotes': 13};
  }

  // ── Dashboard stats ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchDashboard() async {
    // TODO: RESTORE REAL API — MOCK VERSION returns empty map
    await Future.delayed(const Duration(milliseconds: 500));
    return {};
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    // TODO: RESTORE REAL API — MOCK VERSION returns empty
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> markNotificationsRead() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
