class Absence {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectName;
  final String teacherName;
  final String date; // YYYY-MM-DD
  final double hours;
  final bool supervisorApproved;
  final bool justified;

  Absence({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.teacherName,
    required this.date,
    required this.hours,
    required this.supervisorApproved,
    required this.justified,
  });

  factory Absence.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final subject = json['subjectAssignment'] as Map<String, dynamic>;
    final teacher = json['teacher'] as Map<String, dynamic>;
    return Absence(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      studentName: '${student['firstName']} ${student['lastName']}',
      subjectName: subject['name'] as String,
      teacherName: '${teacher['firstName']} ${teacher['lastName']}',
      date: json['date'] as String,
      hours: (json['hours'] as num).toDouble(),
      supervisorApproved: json['supervisorApproved'] as bool,
      justified: json['justified'] as bool,
    );
  }
}

// Regroupement par élève + jour, tel qu'affiché et traité dans les écrans
// superviseur/admin — la justification s'applique par jour, pas par séance isolée.
class AbsenceDayGroup {
  final String studentId;
  final String studentName;
  final String date;
  final List<Absence> absences;

  AbsenceDayGroup({
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.absences,
  });

  double get totalHours => absences.fold(0, (sum, a) => sum + a.hours);
  bool get allApproved => absences.every((a) => a.supervisorApproved);
  bool get allJustified => absences.every((a) => a.justified);
  bool get anyPending => absences.any((a) => !a.justified);

  static List<AbsenceDayGroup> groupByStudentAndDay(List<Absence> absences) {
    final Map<String, List<Absence>> groups = {};
    for (final a in absences) {
      final key = '${a.studentId}_${a.date}';
      groups.putIfAbsent(key, () => []).add(a);
    }
    return groups.values
        .map((list) => AbsenceDayGroup(
              studentId: list.first.studentId,
              studentName: list.first.studentName,
              date: list.first.date,
              absences: list,
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}
