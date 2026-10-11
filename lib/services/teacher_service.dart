import '../models/classroom.dart';
import '../models/access_grant.dart';
import '../models/grade.dart';
import 'api_service.dart';

class TeacherService {
  final ApiService _api;
  TeacherService(this._api);

  // Toutes les salles (structure complète : matières + élèves) — pas sensible,
  // lisible par tout rôle authentifié. On filtre ensuite côté client les matières
  // assignées à l'enseignant courant.
  Future<List<ClassRoom>> getAllClassRooms() async {
    final data = await _api.get('/classrooms');
    return (data as List<dynamic>)
        .map((c) => ClassRoom.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ClassRoom> getClassRoomDetails(String classRoomId) async {
    final data = await _api.get('/classrooms/$classRoomId');
    return ClassRoom.fromJson(data as Map<String, dynamic>);
  }

  // Envoie une demande d'accès à l'admin — ne crée PAS d'accès, juste une notification.
  Future<void> requestAccess(String classRoomId, String subjectAssignmentId) async {
    await _api.post('/access-grants/request', {
      'classRoomId': classRoomId,
      'subjectAssignmentId': subjectAssignmentId,
    });
  }

  Future<List<AccessGrant>> getMyActiveGrants() async {
    final data = await _api.get('/access-grants/mine');
    return (data as List<dynamic>)
        .map((g) => AccessGrant.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  // Notes déjà saisies par MOI pour cette salle/matière — jamais celles des autres enseignants.
  Future<List<Grade>> getMyGrades(String classRoomId, String subjectAssignmentId) async {
    final data = await _api.get(
      '/grades/mine?classRoomId=$classRoomId&subjectAssignmentId=$subjectAssignmentId',
    );
    return (data as List<dynamic>).map((g) => Grade.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<void> createGrade({
    required String studentId,
    required String classRoomId,
    required String subjectAssignmentId,
    required String term,
    required double value,
  }) async {
    await _api.post('/grades', {
      'studentId': studentId,
      'classRoomId': classRoomId,
      'subjectAssignmentId': subjectAssignmentId,
      'term': term,
      'value': value,
    });
  }

  // Motif obligatoire — le serveur refuse si vide, mais on le valide déjà côté
  // client pour un retour immédiat sans aller-retour réseau inutile.
  Future<void> modifyGrade({
    required String gradeId,
    required double newValue,
    required String reason,
  }) async {
    await _api.put('/grades/$gradeId', {'newValue': newValue, 'reason': reason});
  }

  // L'APPEL — volontairement différent de la saisie de notes : aucun accès
  // temporaire requis côté serveur, l'enseignant peut le faire à tout moment
  // pour ses propres matières.
  Future<void> recordAttendance({
    required String classRoomId,
    required String subjectAssignmentId,
    required String term,
    required String date, // YYYY-MM-DD
    required double hours,
    required List<String> absentStudentIds,
  }) async {
    await _api.post('/absences/record', {
      'classRoomId': classRoomId,
      'subjectAssignmentId': subjectAssignmentId,
      'term': term,
      'date': date,
      'hours': hours,
      'absentStudentIds': absentStudentIds,
    });
  }
}
