// lib/features/issues/repositories/issue_repository.dart
// Starts EMPTY — no pre-seeded issues. Users report their own issues.
import '../models/issue.dart';
import '../models/issue_status.dart';

class IssueFilters {
  final IssueStatus? status;
  final String? categoryId;
  final String? wardNumber;
  final String? reporterId;

  const IssueFilters({
    this.status,
    this.categoryId,
    this.wardNumber,
    this.reporterId,
  });

  IssueFilters copyWith({
    IssueStatus? status,
    String? categoryId,
    String? wardNumber,
    String? reporterId,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearWard = false,
  }) {
    return IssueFilters(
      status: clearStatus ? null : (status ?? this.status),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      wardNumber: clearWard ? null : (wardNumber ?? this.wardNumber),
      reporterId: reporterId ?? this.reporterId,
    );
  }
}

enum SortOrder { latest, oldest }

class IssueRepository {
  final List<Issue> _issues = [];
  final Map<String, List<IssueStatusHistory>> _history = {};

  // No seeding — fresh start for every new install

  List<Issue> fetchAllIssues({IssueFilters? filters, SortOrder sort = SortOrder.latest}) {
    var result = List<Issue>.from(_issues);
    if (filters != null) {
      if (filters.status != null) {
        result = result.where((i) => i.status == filters.status).toList();
      }
      if (filters.categoryId != null && filters.categoryId!.isNotEmpty) {
        result = result.where((i) => i.category.id == filters.categoryId).toList();
      }
      if (filters.wardNumber != null && filters.wardNumber!.isNotEmpty) {
        result = result.where((i) => i.location.wardNumber == filters.wardNumber).toList();
      }
    }
    if (sort == SortOrder.latest) {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return result;
  }

  List<Issue> fetchMyIssues(String userId, {IssueFilters? filters, SortOrder sort = SortOrder.latest}) {
    final f = (filters ?? const IssueFilters()).copyWith(reporterId: userId);
    return fetchAllIssues(filters: f, sort: sort)
        .where((i) => i.reporterId == userId)
        .toList();
  }

  Issue? getIssueById(String id) {
    try {
      return _issues.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Issue> searchIssues(String query, {IssueFilters? filters}) {
    final q = query.toLowerCase().trim();
    final result = fetchAllIssues(filters: filters);
    if (q.isEmpty) return result;
    return result.where((i) {
      return i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.location.areaName.toLowerCase().contains(q) ||
          i.category.name.toLowerCase().contains(q);
    }).toList();
  }

  Issue createIssue(Issue issue) {
    _issues.insert(0, issue);
    _history[issue.id] = [
      IssueStatusHistory(
        id: 'hist_${issue.id}_0',
        issueId: issue.id,
        oldStatus: IssueStatus.open,
        newStatus: IssueStatus.open,
        changedAt: issue.createdAt,
        note: 'Issue submitted by citizen',
        changedBy: issue.reporterName.isNotEmpty ? issue.reporterName : 'Citizen',
      ),
    ];
    return issue;
  }

  Issue? updateIssueStatus(String issueId, IssueStatus newStatus, {String? note, String changedBy = 'Admin'}) {
    final idx = _issues.indexWhere((i) => i.id == issueId);
    if (idx == -1) return null;

    final old = _issues[idx];
    final updated = old.copyWith(status: newStatus, updatedAt: DateTime.now());
    _issues[idx] = updated;

    _history[issueId] ??= [];
    _history[issueId]!.add(IssueStatusHistory(
      id: 'hist_${issueId}_${_history[issueId]!.length}',
      issueId: issueId,
      oldStatus: old.status,
      newStatus: newStatus,
      changedAt: DateTime.now(),
      note: note,
      changedBy: changedBy,
    ));

    return updated;
  }

  List<IssueStatusHistory> getIssueHistory(String issueId) {
    return List.from(_history[issueId] ?? []);
  }

  Map<String, int> getIssueCountByCategory() {
    final counts = <String, int>{};
    for (final issue in _issues) {
      counts[issue.category.id] = (counts[issue.category.id] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> getIssueCountByWard() {
    final counts = <String, int>{};
    for (final issue in _issues) {
      counts[issue.location.wardNumber] = (counts[issue.location.wardNumber] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> getIssueCountByStatus() {
    final counts = <String, int>{};
    for (final issue in _issues) {
      counts[issue.status.value] = (counts[issue.status.value] ?? 0) + 1;
    }
    return counts;
  }

  List<MapEntry<DateTime, int>> getIssuesTrend(int days) {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, int>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final count = _issues.where((issue) {
        final d = issue.createdAt;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      result.add(MapEntry(day, count));
    }
    return result;
  }

  int get totalCount => _issues.length;
  int get openCount => _issues.where((i) => i.status == IssueStatus.open).length;
  int get inProgressCount => _issues.where((i) => i.status == IssueStatus.inProgress).length;
  int get resolvedCount => _issues.where((i) => i.status == IssueStatus.resolved).length;
  int get rejectedCount => _issues.where((i) => i.status == IssueStatus.rejected).length;

  List<Issue> getUrgentIssues() =>
      _issues.where((i) => i.isUrgent && i.status == IssueStatus.open).toList();
}
