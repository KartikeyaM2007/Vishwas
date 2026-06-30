// lib/features/issues/models/issue_status.dart

enum IssueStatus {
  open,
  manualReview,
  approved,
  needsMoreProof,
  inProgress,
  resolved,
  rejected;

  String get label {
    switch (this) {
      case IssueStatus.open:
        return 'Pending';
      case IssueStatus.manualReview:
        return 'Manual Review';
      case IssueStatus.approved:
        return 'Approved';
      case IssueStatus.needsMoreProof:
        return 'Needs More Proof';
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
        return 'pending';
      case IssueStatus.manualReview:
        return 'manual_review';
      case IssueStatus.approved:
        return 'approved';
      case IssueStatus.needsMoreProof:
        return 'needs_more_proof';
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
      case 'pending':
      case 'open':
        return IssueStatus.open;
      case 'manual_review':
        return IssueStatus.manualReview;
      case 'approved':
      case 'verified':
      case 'admin_approved':
        return IssueStatus.approved;
      case 'needs_more_proof':
        return IssueStatus.needsMoreProof;
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
