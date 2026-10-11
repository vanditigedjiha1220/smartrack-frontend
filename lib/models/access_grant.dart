enum GrantStatus { active, expired, revoked }

extension GrantStatusParsing on GrantStatus {
  static GrantStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ACTIVE':
        return GrantStatus.active;
      case 'EXPIRED':
        return GrantStatus.expired;
      case 'REVOKED':
        return GrantStatus.revoked;
      default:
        throw ArgumentError('Statut inconnu: $value');
    }
  }
}

class AccessGrant {
  final String id;
  final String teacherId;
  final String teacherName;
  final String classRoomId;
  final String subjectAssignmentId;
  final String classRoomName;
  final String subjectName;
  final DateTime expiresAt;
  final GrantStatus status;

  AccessGrant({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.classRoomId,
    required this.subjectAssignmentId,
    required this.classRoomName,
    required this.subjectName,
    required this.expiresAt,
    required this.status,
  });

  bool get isCurrentlyValid => status == GrantStatus.active && expiresAt.isAfter(DateTime.now());

  Duration get remaining => expiresAt.difference(DateTime.now());

  factory AccessGrant.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'] as Map<String, dynamic>?;
    return AccessGrant(
      id: json['id'] as String,
      teacherId: json['teacherId'] as String,
      teacherName: teacher != null ? '${teacher['firstName']} ${teacher['lastName']}' : '',
      classRoomId: json['classRoomId'] as String,
      subjectAssignmentId: json['subjectAssignmentId'] as String,
      classRoomName: (json['classRoom'] as Map<String, dynamic>)['name'] as String,
      subjectName: (json['subjectAssignment'] as Map<String, dynamic>)['name'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: GrantStatusParsing.fromString(json['status'] as String),
    );
  }
}
