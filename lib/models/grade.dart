class Grade {
  final String id;
  final String studentId;
  final String studentName;
  final double value;
  final double maxValue;

  Grade({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.value,
    required this.maxValue,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return Grade(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      studentName: '${student['firstName']} ${student['lastName']}',
      value: (json['value'] as num).toDouble(),
      maxValue: (json['maxValue'] as num).toDouble(),
    );
  }
}
