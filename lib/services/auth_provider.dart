import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  AppUser? _currentUser;
  bool _mustChangePassword = false;
  bool _isLoading = false;
  String? _lastError;

  // Refresh token de la session EN COURS — gardé en mémoire uniquement (jamais
  // écrit sur le disque directement par le provider). Sert uniquement à
  // proposer "Activer la connexion par empreinte ?" juste après un login réussi ;
  // si l'utilisateur accepte, c'est ApiService.enableBiometricLogin() qui l'écrit
  // réellement dans le stockage chiffré. Si l'utilisateur refuse, cette valeur
  // est simplement oubliée à la fermeture de l'app — rien n'est jamais persisté
  // sans action explicite de l'utilisateur.
  String? _lastRefreshToken;

  AuthProvider(this._api);

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isAuthenticated => _currentUser != null;
  String? get lastRefreshToken => _lastRefreshToken;

  bool get mustChangePassword => _mustChangePassword;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _api.login(email, password);
      _currentUser = result.user;
      _mustChangePassword = result.mustChangePassword;
      _lastRefreshToken = result.refreshToken;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = "Impossible de joindre le serveur. Vérifiez l'adresse configurée et le réseau.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Connexion par empreinte — appelée UNIQUEMENT après que l'invite biométrique
  // native (voir BiometricService) a déjà confirmé l'identité de l'utilisateur.
  // Aucun mot de passe n'est demandé ici : le refresh token stocké fait foi.
  Future<bool> loginWithBiometrics() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _api.loginWithRefreshToken();
      _currentUser = result.user;
      _mustChangePassword = result.mustChangePassword;
      _lastRefreshToken = result.refreshToken;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = "Impossible de joindre le serveur. Vérifiez l'adresse configurée et le réseau.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // À appeler seulement après confirmation biométrique réussie côté écran —
  // c'est cette étape qui écrit réellement le refresh token dans le stockage
  // chiffré, activant la connexion par empreinte pour les prochaines fois.
  Future<void> enableBiometricLogin() async {
    if (_lastRefreshToken == null) return;
    await _api.enableBiometricLogin(_lastRefreshToken!);
  }

  Future<void> disableBiometricLogin() async {
    await _api.disableBiometricLogin();
  }

  Future<bool> isBiometricLoginEnabled() => _api.isBiometricLoginEnabled();

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _currentUser = result.user;
      _mustChangePassword = result.mustChangePassword;
      _lastRefreshToken = result.refreshToken;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = "Impossible de joindre le serveur. Réessayez.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _currentUser = null;
    _mustChangePassword = false;
    _lastRefreshToken = null;
    notifyListeners();
  }
}