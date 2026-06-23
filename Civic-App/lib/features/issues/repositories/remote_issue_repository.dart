// lib/features/issues/repositories/remote_issue_repository.dart
// Connects CityPulse Flutter app to the Django REST API backend.
// Authentication token is automatically attached via ApiService.

import 'dart:io';
import '../../../core/services/api_service.dart';
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
  final imageUrl = json['image_url'] as String?;
  return Issue(
    id: json['id'].toString(),
    title:
        '${(json['issue_type'] as String? ?? 'Issue').replaceAll('_', ' ').toUpperCase()}',
    description: json['complaint_desc'] as String? ?? json['description'] as String? ?? '',
    category: _categoryFromType(json['issue_type'] as String? ?? ''),
    location: IssueLocation(
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      areaName: 'Detected Location',
      wardNumber: '',
    ),
    status: _statusFromValue(json['status'] as String?),
    createdAt:
        DateTime.tryParse(json['submitted_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['submitted_at'] as String? ?? '') ?? DateTime.now(),
    reporterId: json['username']?.toString() ?? '',
    reporterName: json['username']?.toString() ?? 'Citizen',
    attachments: imageUrl != null ? [imageUrl] : [],
    upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
    isUrgent: ((json['severity'] as num?)?.toInt() ?? 0) >= 7,
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
    final complaintDescription =
        data['complaint_description'] as String? ?? '';

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
    // Final submit is a UI confirmation step.
    await Future.delayed(const Duration(milliseconds: 200));

    // MOCK: Add to base IssueRepository so it shows up in "My Issues"
    final newIssue = Issue(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      title: '${(_tempIssueType ?? "Issue").toUpperCase()} Report',
      description: description,
      category: _categoryFromType(_tempIssueType ?? ''),
      location: IssueLocation(
        latitude: _tempLat ?? 0.0,
        longitude: _tempLng ?? 0.0,
        areaName: 'Detected Location',
        wardNumber: 'Ward 1',
      ),
      status: IssueStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      reporterId: 'user_001', // Default mock user
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
    try {
      final response = await ApiService.get('/complaints');
      if (ApiService.isSuccess(response)) {
        final decoded = ApiService.decodeResponse(response);
        final dataList = decoded['data'] as List<dynamic>? ?? [];
        final issues = dataList
            .map((json) => _issueFromJson(json as Map<String, dynamic>))
            .toList();

        // Apply fallback sorting
        if (sort == SortOrder.latest) {
          issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          issues.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        
        // Update the base repository to keep it in sync for synchronous fetches
        // Since _issues is private in IssueRepository, we can't clear/addAll directly.
        // For a true remote repository pattern, returning the issues here is enough.
        
        return issues;
      }
    } catch (_) {}
    return fetchAllIssues(filters: filters, sort: sort);
  }

  // ── Fetch MY complaints ────────────────────────────────────────────────────
  Future<List<Issue>> fetchMyComplaints() async {
    // NOTE: If you have a specific endpoint for user complaints like '/my_complaints', you can use it here.
    // For now, it fetches ALL complaints and filters them by the current logged-in username "Praveen"
    try {
      final response = await ApiService.get('/complaints');
      if (ApiService.isSuccess(response)) {
        final decoded = ApiService.decodeResponse(response);
        final dataList = decoded['data'] as List<dynamic>? ?? [];
        final issues = dataList
            .map((json) => _issueFromJson(json as Map<String, dynamic>))
            .toList();
            
        // Assuming current user ID/Username mapping (hardcoded to 'Praveen' for the demo logic based on provided JSON)
        // Replace 'Praveen' with the actual logged-in user name/id from authController if available inside the UI callback
        return issues.where((i) => i.reporterId == 'Praveen' || i.reporterName == 'Praveen').toList(); 
      }
    } catch (_) {}
    return fetchMyIssues('user_001');
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
