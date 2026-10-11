enum SubjectCategory { litteraire, scientifique, autre }

// Fonctions simples plutôt qu'une extension : contourne un problème de résolution
// à l'exécution observé sur certains appareils avec les méthodes d'extension sur enum.
SubjectCategory subjectCategoryFromString(String value) {
  switch (value.toUpperCase()) {
    case 'LITTERAIRE':
      return SubjectCategory.litteraire;
    case 'SCIENTIFIQUE':
      return SubjectCategory.scientifique;
    default:
      return SubjectCategory.autre;
  }
}

String subjectCategoryApiValue(SubjectCategory category) {
  switch (category) {
    case SubjectCategory.litteraire:
      return 'LITTERAIRE';
    case SubjectCategory.scientifique:
      return 'SCIENTIFIQUE';
    case SubjectCategory.autre:
      return 'AUTRE';
  }
}

String subjectCategoryLabel(SubjectCategory category) {
  switch (category) {
    case SubjectCategory.litteraire:
      return 'Littéraire';
    case SubjectCategory.scientifique:
      return 'Scientifique';
    case SubjectCategory.autre:
      return 'Autre';
  }
}

class SubjectAssignment {
  final String id;
  final String name;
  final SubjectCategory category;
  final double coefficient;
  final String teacherId;
  final String teacherFirstName;
  final String teacherLastName;

  SubjectAssignment({
    required this.id,
    required this.name,
    required this.category,
    required this.coefficient,
    required this.teacherId,
    required this.teacherFirstName,
    required this.teacherLastName,
  });

  factory SubjectAssignment.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'] as Map<String, dynamic>;
    return SubjectAssignment(
      id: json['id'] as String,
      name: json['name'] as String,
      category: subjectCategoryFromString(json['category'] as String? ?? 'AUTRE'),
      coefficient: (json['coefficient'] as num).toDouble(),
      teacherId: teacher['id'] as String,
      teacherFirstName: teacher['firstName'] as String,
      teacherLastName: teacher['lastName'] as String,
    );
  }
}

class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String matricule;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.matricule,
  });

  String get fullName => '$firstName $lastName';

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      matricule: json['matricule'] as String,
    );
  }
}

class ClassRoom {
  final String id;
  final String name;
  final String level;
  final String year;
  final String? principalTeacherId;
  final String? principalTeacherName;
  final List<SubjectAssignment> subjects;
  final List<Student> students;

  ClassRoom({
    required this.id,
    required this.name,
    required this.level,
    required this.year,
    this.principalTeacherId,
    this.principalTeacherName,
    this.subjects = const [],
    this.students = const [],
  });

  factory ClassRoom.fromJson(Map<String, dynamic> json) {
    final principalTeacher = json['principalTeacher'] as Map<String, dynamic>?;
    return ClassRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as String,
      year: json['year'] as String,
      principalTeacherId: principalTeacher?['id'] as String?,
      principalTeacherName:
          principalTeacher != null ? '${principalTeacher['firstName']} ${principalTeacher['lastName']}' : null,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((s) => SubjectAssignment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      students: (json['students'] as List<dynamic>?)
              ?.map((s) => Student.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}