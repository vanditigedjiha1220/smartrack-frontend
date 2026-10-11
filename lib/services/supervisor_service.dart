import '../models/grade.dart';
import '../models/absence.dart';
import '../models/bulletin.dart';
import '../models/classroom.dart';
import 'api_service.dart';

class SupervisorGradeRecord {
  final String id;
  final String studentName;
  final String subjectName;
  final String teacherName;
  final double value;
  final double maxValue;
  final int modificationCount;

  SupervisorGradeRecord({
    required this.id,
    required this.studentName,
    required this.subjectName,
    required this.teacherName,
    required this.value,
    required this.maxValue,
    required this.modificationCount,
  });

  factory SupervisorGradeRecord.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final subject = json['subjectAssignment'] as Map<String, dynamic>;
    final teacher = json['teacher'] as Map<String, dynamic>;
    final history = json['modificationHistory'] as List<dynamic>? ?? [];
    return SupervisorGradeRecord(
      id: json['id'] as String,
      studentName: '${student['firstName']} ${student['lastName']}',
      subjectName: subject['name'] as String,
      teacherName: '${teacher['firstName']} ${teacher['lastName']}',
      value: (json['value'] as num).toDouble(),
      maxValue: (json['maxValue'] as num).toDouble(),
      modificationCount: history.length,
    );
  }
}

class SupervisorService {
  final ApiService _api;
  SupervisorService(this._api);

  // Lecture complète — réservée au rôle SUPERVISOR côté serveur (RolesGuard).
  Future<List<SupervisorGradeRecord>> getAllGrades({String? classRoomId}) async {
    final query = classRoomId != null ? '?classRoomId=$classRoomId' : '';
    final data = await _api.get('/grades$query');
    return (data as List<dynamic>)
        .map((g) => SupervisorGradeRecord.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  // --- Absences ---

  Future<List<Absence>> getAllAbsences({String? classRoomId}) async {
    final query = classRoomId != null ? '?classRoomId=$classRoomId' : '';
    final data = await _api.get('/absences$query');
    return (data as List<dynamic>).map((a) => Absence.fromJson(a as Map<String, dynamic>)).toList();
  }

  // Approuve pour UN élève, UN jour précis — jamais toutes ses absences.
  Future<void> approveJustification({required String studentId, required String date}) async {
    await _api.post('/absences/approve-justification', {'studentId': studentId, 'date': date});
  }

  // --- Salles (nécessaire pour choisir quelle salle/trimestre consulter) ---

  Future<List<ClassRoom>> getClassRooms() async {
    final data = await _api.get('/classrooms');
    return (data as List<dynamic>).map((c) => ClassRoom.fromJson(c as Map<String, dynamic>)).toList();
  }

  // --- Bulletins ---

  Future<List<BulletinListItem>> getBulletinsForClass({required String classRoomId, required String term}) async {
    final data = await _api.get('/bulletins?classRoomId=$classRoomId&term=$term');
    return (data as List<dynamic>).map((b) => BulletinListItem.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<BulletinDetail> getBulletinDetail(String bulletinId) async {
    final data = await _api.get('/bulletins/$bulletinId');
    return BulletinDetail.fromJson(data as Map<String, dynamic>);
  }

  // Signature positionnelle (bulletinId, comment) pour matcher exactement le
  // callback attendu par BulletinViewScreen — comment vide = garder le mot auto-généré.
  Future<void> signBulletin(String bulletinId, String comment) async {
    await _api.post('/bulletins/$bulletinId/sign', {if (comment.isNotEmpty) 'comment': comment});
  }
}
