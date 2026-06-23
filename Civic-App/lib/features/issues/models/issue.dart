// lib/features/issues/models/issue.dart
import 'category.dart';
import 'location.dart';
import 'issue_status.dart';

class Issue {
  final String id;
  final String title;
  final String description;
  final IssueCategory category;
  final IssueLocation location;
  final IssueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String reporterId;
  final String reporterName;
  final List<String> attachments; // mock image asset paths or urls
  final int upvotes;
  final bool isUrgent;

  const Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.reporterId,
    required this.reporterName,
    this.attachments = const [],
    this.upvotes = 0,
    this.isUrgent = false,
  });

  Issue copyWith({
    String? id,
    String? title,
    String? description,
    IssueCategory? category,
    IssueLocation? location,
    IssueStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterId,
    String? reporterName,
    List<String>? attachments,
    int? upvotes,
    bool? isUrgent,
  }) {
    return Issue(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      attachments: attachments ?? this.attachments,
      upvotes: upvotes ?? this.upvotes,
      isUrgent: isUrgent ?? this.isUrgent,
    );
  }
}

class IssueStatusHistory {
  final String id;
  final String issueId;
  final IssueStatus oldStatus;
  final IssueStatus newStatus;
  final DateTime changedAt;
  final String? note;
  final String changedBy;

  const IssueStatusHistory({
    required this.id,
    required this.issueId,
    required this.oldStatus,
    required this.newStatus,
    required this.changedAt,
    this.note,
    required this.changedBy,
  });
}
