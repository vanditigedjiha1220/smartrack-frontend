import '../models/classroom.dart';
import '../models/access_grant.dart';
import '../models/user.dart';
import '../models/bulletin.dart';
import '../models/absence.dart';
import 'api_service.dart';

class AdminService {
  final ApiService _api;
  AdminService(this._api);

  // --- Salles ---

  Future<List<ClassRoom>> getClassRooms() async {
    final data = await _api.get('/classrooms');
    return (data as List<dynamic>)
        .map((c) => ClassRoom.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ClassRoom> getClassRoomDetails(String id) async {
    final data = await _api.get('/classrooms/$id');
    return ClassRoom.fromJson(data as Map<String, dynamic>);
  }

  Future<void> createClassRoom({required String name, required String level, required String year}) async {
    await _api.post('/classrooms', {'name': name, 'level': level, 'year': year});
  }

  Future<void> addSubject({
    required String classRoomId,
    required String name,
    required SubjectCategory category,
    required double coefficient,
    required String teacherId,
  }) async {
    await _api.post('/classrooms/$classRoomId/subjects', {
      'name': name,
      'category': subjectCategoryApiValue(category),
      'coefficient': coefficient,
      'teacherId': teacherId,
    });
  }

  Future<void> addStudent({
    required String classRoomId,
    required String firstName,
    required String lastName,
    required String matricule,
  }) async {
    await _api.post('/classrooms/$classRoomId/students', {
      'firstName': firstName,
      'lastName': lastName,
      'matricule': matricule,
    });
  }

  // Le professeur principal doit déjà enseigner une matière dans cette salle —
  // vérifié côté serveur.
  Future<void> setPrincipalTeacher({required String classRoomId, required String teacherId}) async {
    await _api.patch('/classrooms/$classRoomId/principal-teacher', {'teacherId': teacherId});
  }

  // --- Comptes ---

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final roleStr = switch (role) {
      UserRole.admin => 'ADMIN',
      UserRole.teacher => 'TEACHER',
      UserRole.supervisor => 'SUPERVISOR',
    };
    final data = await _api.get('/users?role=$roleStr');
    return (data as List<dynamic>).map((u) => AppUser.fromJson(u as Map<String, dynamic>)).toList();
  }

  Future<void> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final roleStr = switch (role) {
      UserRole.admin => 'ADMIN',
      UserRole.teacher => 'TEACHER',
      UserRole.supervisor => 'SUPERVISOR',
    };
    await _api.post('/users', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'role': roleStr,
    });
  }

  // --- Accès temporaires ---
  // L'admin voit ici la liste des accès (qui/quelle salle/quel statut) — jamais de note.

  Future<List<AccessGrant>> getAllGrants() async {
    final data = await _api.get('/access-grants');
    return (data as List<dynamic>).map((g) => AccessGrant.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<void> grantAccess({
    required String teacherId,
    required String classRoomId,
    required String subjectAssignmentId,
    required DateTime expiresAt,
    String? reason,
  }) async {
    await _api.post('/access-grants/grant', {
      'teacherId': teacherId,
      'classRoomId': classRoomId,
      'subjectAssignmentId': subjectAssignmentId,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> revokeAccess(String grantId) async {
    await _api.post('/access-grants/$grantId/revoke', {});
  }

  // --- Bulletins ---
  // Le serveur ne renvoie ici QUE le résumé agrégé (élève, moyenne, rang) —
  // jamais la grille de notes qui a servi au calcul.

  Future<List<BulletinSummary>> generateBulletins({
    required String classRoomId,
    required String term,
  }) async {
    final data = await _api.post('/bulletins/generate', {'classRoomId': classRoomId, 'term': term});
    return (data as List<dynamic>)
        .map((b) => BulletinSummary.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<BulletinDetail> getBulletinDetail(String bulletinId) async {
    final data = await _api.get('/bulletins/$bulletinId');
    return BulletinDetail.fromJson(data as Map<String, dynamic>);
  }

  // Contrairement à generateBulletins (qui ne renvoie pas d'id), cette liste
  // inclut l'id de chaque bulletin — nécessaire pour ouvrir le document détaillé.
  Future<List<BulletinListItem>> listBulletins({required String classRoomId, required String term}) async {
    final data = await _api.get('/bulletins?classRoomId=$classRoomId&term=$term');
    return (data as List<dynamic>).map((b) => BulletinListItem.fromJson(b as Map<String, dynamic>)).toList();
  }

  // --- Absences ---
  // L'admin voit l'ensemble des absences (fait objectif, pas une note protégée),
  // mais ne peut confirmer une justification qu'après approbation du superviseur —
  // vérifié côté serveur, pas seulement côté écran.

  Future<List<Absence>> getAllAbsences({String? classRoomId}) async {
    final query = classRoomId != null ? '?classRoomId=$classRoomId' : '';
    final data = await _api.get('/absences/admin$query');
    return (data as List<dynamic>).map((a) => Absence.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<void> confirmJustification({required String studentId, required String date}) async {
    await _api.post('/absences/confirm-justification', {'studentId': studentId, 'date': date});
  }

  // --- Journal d'audit — métadonnées seulement, jamais les valeurs de notes ---

  Future<List<Map<String, dynamic>>> getAuditMetadata({String? classRoomId}) async {
    final query = classRoomId != null ? '?classRoomId=$classRoomId' : '';
    final data = await _api.get('/audit-log/metadata$query');
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}