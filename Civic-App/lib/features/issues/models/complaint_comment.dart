class ComplaintComment {
  final int id;
  final String complaintId;
  final int? parentCommentId;
  final String userId;
  final String username;
  final String userRole;
  final String body;
  final bool isVerifiedUser;
  final int upvotes;
  final int downvotes;
  final bool isDeleted;
  final DateTime createdAt;
  final List<ComplaintComment> replies;

  const ComplaintComment({
    required this.id,
    required this.complaintId,
    required this.parentCommentId,
    required this.userId,
    required this.username,
    required this.userRole,
    required this.body,
    required this.isVerifiedUser,
    required this.upvotes,
    required this.downvotes,
    required this.isDeleted,
    required this.createdAt,
    this.replies = const [],
  });

  factory ComplaintComment.fromJson(Map<String, dynamic> json) {
    return ComplaintComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      complaintId: json['complaint_id']?.toString() ?? '',
      parentCommentId: (json['parent_comment_id'] as num?)?.toInt(),
      userId: json['user_id']?.toString() ?? 'guest',
      username: json['username']?.toString() ?? 'Guest Citizen',
      userRole: json['user_role']?.toString() ?? 'citizen',
      body: json['body']?.toString() ?? '',
      isVerifiedUser: json['is_verified_user'] == true,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      replies: (json['replies'] as List<dynamic>? ?? const [])
          .map((reply) =>
              ComplaintComment.fromJson((reply as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
