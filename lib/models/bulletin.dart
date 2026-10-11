class BulletinListItem {
  final String id;
  final String studentName;
  final double average;
  final int? rank;

  BulletinListItem({required this.id, required this.studentName, required this.average, this.rank});

  factory BulletinListItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return BulletinListItem(
      id: json['id'] as String,
      studentName: '${student['firstName']} ${student['lastName']}',
      average: (json['average'] as num).toDouble(),
      rank: json['rank'] as int?,
    );
  }
}

class BulletinSummary {
  final String studentId;
  final String studentName;
  final double average;
  final int rank;

  BulletinSummary({
    required this.studentId,
    required this.studentName,
    required this.average,
    required this.rank,
  });

  factory BulletinSummary.fromJson(Map<String, dynamic> json) {
    return BulletinSummary(
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      average: (json['average'] as num).toDouble(),
      rank: json['rank'] as int,
    );
  }
}

class BulletinSubjectDetail {
  final String subjectName;
  final double grade;
  final double coefficient;
  final double weighted;

  BulletinSubjectDetail({
    required this.subjectName,
    required this.grade,
    required this.coefficient,
    required this.weighted,
  });

  factory BulletinSubjectDetail.fromJson(Map<String, dynamic> json) {
    return BulletinSubjectDetail(
      subjectName: json['subjectName'] as String,
      grade: (json['grade'] as num).toDouble(),
      coefficient: (json['coefficient'] as num).toDouble(),
      weighted: (json['weighted'] as num).toDouble(),
    );
  }
}

class BulletinDetail {
  final String id;
  final String studentName;
  final String classRoomName;
  final String term;
  final double average;
  final int rank;
  final String schoolName;
  final String? principalTeacherName;
  final double totalAbsenceHours;
  final double justifiedAbsenceHours;
  final double unjustifiedAbsenceHours;
  final String? signedByName;
  final DateTime? signedAt;
  final String? supervisorComment;
  final List<BulletinSubjectDetail> subjectDetails;

  BulletinDetail({
    required this.id,
    required this.studentName,
    required this.classRoomName,
    required this.term,
    required this.average,
    required this.rank,
    required this.schoolName,
    this.principalTeacherName,
    required this.totalAbsenceHours,
    required this.justifiedAbsenceHours,
    required this.unjustifiedAbsenceHours,
    this.signedByName,
    this.signedAt,
    this.supervisorComment,
    required this.subjectDetails,
  });

  bool get isSigned => signedAt != null;

  factory BulletinDetail.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final classRoom = json['classRoom'] as Map<String, dynamic>;
    final signedBy = json['signedBy'] as Map<String, dynamic>?;
    final details = json['subjectDetails'] as List<dynamic>;

    return BulletinDetail(
      id: json['id'] as String,
      studentName: '${student['firstName']} ${student['lastName']}',
      classRoomName: classRoom['name'] as String,
      term: json['term'] as String,
      average: (json['average'] as num).toDouble(),
      rank: json['rank'] as int,
      schoolName: json['schoolName'] as String? ?? 'Établissement scolaire',
      principalTeacherName: json['principalTeacherName'] as String?,
      totalAbsenceHours: (json['totalAbsenceHours'] as num?)?.toDouble() ?? 0,
      justifiedAbsenceHours: (json['justifiedAbsenceHours'] as num?)?.toDouble() ?? 0,
      unjustifiedAbsenceHours: (json['unjustifiedAbsenceHours'] as num?)?.toDouble() ?? 0,
      signedByName: signedBy != null ? '${signedBy['firstName']} ${signedBy['lastName']}' : null,
      signedAt: json['signedAt'] != null ? DateTime.parse(json['signedAt'] as String) : null,
      supervisorComment: json['supervisorComment'] as String?,
      subjectDetails: details.map((d) => BulletinSubjectDetail.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}
