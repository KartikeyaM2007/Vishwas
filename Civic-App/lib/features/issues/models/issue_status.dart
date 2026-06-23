// lib/features/issues/models/issue_status.dart

enum IssueStatus {
  open,
  inProgress,
  resolved,
  rejected;

  String get label {
    switch (this) {
      case IssueStatus.open:
        return 'Open';
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.resolved:
        return 'Resolved';
      case IssueStatus.rejected:
        return 'Rejected';
    }
  }

  String get value {
    switch (this) {
      case IssueStatus.open:
        return 'open';
      case IssueStatus.inProgress:
        return 'in_progress';
      case IssueStatus.resolved:
        return 'resolved';
      case IssueStatus.rejected:
        return 'rejected';
    }
  }

  static IssueStatus fromValue(String value) {
    switch (value) {
      case 'in_progress':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      case 'rejected':
        return IssueStatus.rejected;
      default:
        return IssueStatus.open;
    }
  }
}

enum UserRole {
  citizen,
  admin;

  String get label {
    switch (this) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
