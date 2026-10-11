enum UserRole { admin, teacher, supervisor }

extension UserRoleParsing on UserRole {
  // Le backend envoie le rôle en majuscules ("ADMIN", "TEACHER", "SUPERVISOR"),
  // exactement l'enum Role de user.entity.ts côté serveur.
  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'TEACHER':
        return UserRole.teacher;
      case 'SUPERVISOR':
        return UserRole.supervisor;
      default:
        throw ArgumentError('Rôle inconnu: $value');
    }
  }
}

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;

  // Vrai juste après un login avec le mot de passe temporaire donné par l'admin.
  // Redondant avec AuthResult.mustChangePassword (voir api_service.dart) mais
  // gardé ici aussi pour que tout code qui ne manipule qu'un AppUser (sans passer
  // par AuthResult) puisse encore lire cette info si besoin.
  final bool mustChangePassword;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.mustChangePassword = false,
  });

  String get fullName => '$firstName $lastName';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      role: UserRoleParsing.fromString(json['role'] as String),
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    );
  }
}