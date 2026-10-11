import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user.dart';

// Exception métier propre, pour que les écrans affichent le message serveur
// tel quel (ex: "Identifiants invalides", "Aucun accès actif...") plutôt
// qu'une erreur technique brute.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

// Résultat d'une authentification (login, refresh, ou changement de mot de passe) —
// regroupe l'utilisateur, l'indicateur de mot de passe temporaire, ET le refresh
// token — ce dernier n'est utile qu'à l'écran de login, pour proposer d'activer
// la connexion par empreinte juste après un login réussi.
class AuthResult {
  final AppUser user;
  final bool mustChangePassword;
  final String refreshToken;
  AuthResult({required this.user, required this.mustChangePassword, required this.refreshToken});
}

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';

  String? _cachedToken;

  // --- Gestion du token de session ---

  Future<String?> getToken() async {
    _cachedToken ??= await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<void> _saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasStoredToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // --- Gestion du refresh token (connexion par empreinte) ---
  // Stocké SÉPARÉMENT du token de session, dans le même coffre chiffré par l'OS.
  // Sa seule présence ici signifie "la connexion par empreinte est activée sur
  // cet appareil" — c'est ce que vérifie isBiometricLoginEnabled().

  Future<void> enableBiometricLogin(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> disableBiometricLogin() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> isBiometricLoginEnabled() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  // Rotation silencieuse : à chaque nouvelle session (login normal, refresh,
  // changement de mot de passe), si la connexion par empreinte était déjà
  // activée, on remplace l'ancien refresh token par le nouveau — sans que
  // l'utilisateur ait à refaire la manip d'activation à chaque fois.
  Future<void> _rotateRefreshTokenIfEnabled(String newRefreshToken) async {
    if (await isBiometricLoginEnabled()) {
      await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
    }
  }

  // --- Authentification ---

  // Point d'entrée unique pour les 3 rôles — le rôle retourné dans `user.role`
  // détermine ensuite, côté écran de login, vers quel tableau de bord naviguer.
  // Si mustChangePassword est vrai, l'app DOIT afficher l'écran de changement
  // obligatoire avant toute navigation vers un tableau de bord : le serveur
  // refusera de toute façon tout autre appel tant que ce n'est pas fait.
  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, body['message'] ?? 'Erreur de connexion');
    }

    await _saveToken(body['accessToken'] as String);
    final refreshToken = body['refreshToken'] as String;
    await _rotateRefreshTokenIfEnabled(refreshToken);

    final userJson = body['user'] as Map<String, dynamic>;
    return AuthResult(
      user: AppUser.fromJson(userJson),
      mustChangePassword: userJson['mustChangePassword'] as bool? ?? false,
      refreshToken: refreshToken,
    );
  }

  // Échange le refresh token stocké (déverrouillé par empreinte digitale côté
  // écran) contre une session fraîche — AUCUN mot de passe redemandé.
  Future<AuthResult> loginWithRefreshToken() async {
    final storedRefreshToken = await _storage.read(key: _refreshTokenKey);
    if (storedRefreshToken == null) {
      throw ApiException(401, "Aucune connexion par empreinte enregistrée sur cet appareil");
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': storedRefreshToken}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      // Refresh token expiré/invalide (ex: 30 jours passés) — on désactive
      // proprement la connexion par empreinte plutôt que de la laisser
      // silencieusement cassée à chaque tentative future.
      await disableBiometricLogin();
      throw ApiException(
        response.statusCode,
        body['message'] ?? 'Connexion par empreinte expirée — reconnectez-vous avec votre mot de passe',
      );
    }

    await _saveToken(body['accessToken'] as String);
    final newRefreshToken = body['refreshToken'] as String;
    await _rotateRefreshTokenIfEnabled(newRefreshToken); // rotation même chemin que login()

    final userJson = body['user'] as Map<String, dynamic>;
    return AuthResult(
      user: AppUser.fromJson(userJson),
      mustChangePassword: userJson['mustChangePassword'] as bool? ?? false,
      refreshToken: newRefreshToken,
    );
  }

  // Remplace le mot de passe temporaire par un mot de passe choisi par l'utilisateur.
  // Reste joignable même quand le compte est encore en état "mustChangePassword"
  // (voir @AllowPendingPassword() côté backend) — c'est le seul appel qui l'est.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    final body = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : {};

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, body['message']?.toString() ?? 'Erreur serveur');
    }

    // Le backend réémet un token frais (mustChangePassword=false dedans) : on
    // remplace l'ancien pour que les appels suivants passent enfin les guards.
    await _saveToken(body['accessToken'] as String);
    final refreshToken = body['refreshToken'] as String;
    await _rotateRefreshTokenIfEnabled(refreshToken);

    final userJson = body['user'] as Map<String, dynamic>;
    return AuthResult(
      user: AppUser.fromJson(userJson),
      mustChangePassword: userJson['mustChangePassword'] as bool? ?? false,
      refreshToken: refreshToken,
    );
  }

  // Déconnexion complète : efface aussi la connexion par empreinte. Un utilisateur
  // qui se déconnecte explicitement doit redonner son mot de passe la prochaine
  // fois, pas juste son empreinte — sinon "se déconnecter" ne voudrait plus dire
  // grand-chose sur un appareil partagé.
 Future<void> logout() async {
  await clearToken();
}

  // --- Requêtes génériques authentifiées ---
  // Toutes les routes protégées passent par ici pour ne jamais oublier
  // l'en-tête Authorization, et pour centraliser la gestion des erreurs 401/403.

  Future<dynamic> get(String path) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode == 401) {
      // Token invalide/expiré — l'appelant doit rediriger vers le login.
      throw ApiException(401, body?['message'] ?? 'Session expirée, reconnectez-vous');
    }
    if (response.statusCode == 403) {
      // Peut aussi survenir si mustChangePassword est encore vrai côté serveur
      // (ex: ancien token réutilisé) — le message du backend l'explique clairement.
      throw ApiException(403, body?['message'] ?? 'Accès refusé');
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, body?['message']?.toString() ?? 'Erreur serveur');
    }

    return body;
  }
}