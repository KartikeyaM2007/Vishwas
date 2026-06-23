// lib/features/issues/providers/issue_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/remote_issue_repository.dart';
import '../repositories/issue_repository.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';

// ── Repository provider (remote) ─────────────────────────────────────────────
final remoteIssueRepositoryProvider = Provider<RemoteIssueRepository>((ref) {
  return RemoteIssueRepository();
});

// Keep backward-compat alias used by screens that import issueRepositoryProvider
final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  return ref.watch(remoteIssueRepositoryProvider);
});

// ── Filter State ─────────────────────────────────────────────────────────────
class IssueFilterState {
  final IssueStatus? status;
  final String? categoryId;
  final String? wardNumber;
  final SortOrder sortOrder;

  const IssueFilterState({
    this.status,
    this.categoryId,
    this.wardNumber,
    this.sortOrder = SortOrder.latest,
  });

  IssueFilterState copyWith({
    IssueStatus? status,
    String? categoryId,
    String? wardNumber,
    SortOrder? sortOrder,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearWard = false,
  }) {
    return IssueFilterState(
      status: clearStatus ? null : (status ?? this.status),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      wardNumber: clearWard ? null : (wardNumber ?? this.wardNumber),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class IssueFilterNotifier extends StateNotifier<IssueFilterState> {
  IssueFilterNotifier() : super(const IssueFilterState());

  void setStatus(IssueStatus? status) {
    state = state.copyWith(clearStatus: status == null, status: status);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(clearCategory: categoryId == null, categoryId: categoryId);
  }

  void setWard(String? wardNumber) {
    state = state.copyWith(clearWard: wardNumber == null, wardNumber: wardNumber);
  }

  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void resetAll() {
    state = const IssueFilterState();
  }
}

final issueFilterProvider =
    StateNotifierProvider<IssueFilterNotifier, IssueFilterState>(
        (ref) => IssueFilterNotifier());

// ── All Issues (async, remote) ────────────────────────────────────────────────
final allIssuesProvider = FutureProvider.autoDispose<List<Issue>>((ref) async {
  final repo = ref.watch(remoteIssueRepositoryProvider);
  final filters = ref.watch(issueFilterProvider);
  return repo.fetchComplaints(
    filters: IssueFilters(
      status: filters.status,
      categoryId: filters.categoryId,
      wardNumber: filters.wardNumber,
    ),
    sort: filters.sortOrder,
  );
});

// ── My Issues filter ─────────────────────────────────────────────────────────
class MyIssueFilterNotifier extends StateNotifier<IssueFilterState> {
  MyIssueFilterNotifier() : super(const IssueFilterState());

  void setStatus(IssueStatus? status) {
    state = state.copyWith(clearStatus: status == null, status: status);
  }

  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
  }
}

final myIssueFilterProvider =
    StateNotifierProvider<MyIssueFilterNotifier, IssueFilterState>(
        (ref) => MyIssueFilterNotifier());

// ── My Complaints (async, remote) ─────────────────────────────────────────────
final myIssuesProvider = FutureProvider.autoDispose<List<Issue>>((ref) async {
  final repo = ref.watch(remoteIssueRepositoryProvider);
  return repo.fetchMyComplaints();
});

// ── Dashboard stats (async) ───────────────────────────────────────────────────
final dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(remoteIssueRepositoryProvider);
  return repo.fetchDashboard();
});

// ── Notifications (async) ────────────────────────────────────────────────────
final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(remoteIssueRepositoryProvider);
  return repo.fetchNotifications();
});

// ── Search ────────────────────────────────────────────────────────────────────
class SearchNotifier extends StateNotifier<String> {
  SearchNotifier() : super('');

  void update(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    StateNotifierProvider<SearchNotifier, String>((ref) => SearchNotifier());

final searchResultsProvider =
    FutureProvider.autoDispose<List<Issue>>((ref) async {
  final repo = ref.watch(remoteIssueRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(issueFilterProvider);
  final all = await repo.fetchComplaints(
    filters: IssueFilters(
      status: filters.status,
      categoryId: filters.categoryId,
    ),
  );
  if (query.trim().isEmpty) return all;
  final q = query.toLowerCase();
  return all
      .where((i) =>
          i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.location.areaName.toLowerCase().contains(q) ||
          i.category.name.toLowerCase().contains(q))
      .toList();
});

// ── Single Issue ──────────────────────────────────────────────────────────────
final issueByIdProvider =
    FutureProvider.autoDispose.family<Issue?, String>((ref, id) async {
  final all = await ref.watch(allIssuesProvider.future);
  try {
    return all.firstWhere((i) => i.id == id);
  } catch (_) {
    return null;
  }
});

// ── Loading flag (kept for backward compat) ───────────────────────────────────
final isLoadingProvider = StateProvider<bool>((ref) => false);


