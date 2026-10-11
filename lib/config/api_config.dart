import 'package:shared_preferences/shared_preferences.dart';

// Gère l'adresse IP locale du serveur backend. Chaque établissement a une IP
// différente sur son propre réseau WiFi, donc c'est configurable dans l'app
// (écran de paramètres au premier lancement) plutôt que codé en dur.
class ApiConfig {
  static const _storageKey = 'server_base_url';
  static const String defaultBaseUrl = 'http://192.168.1.100:3000';

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_storageKey) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    // Normalise: retire un éventuel "/" final pour éviter les doubles slashs
    // dans les URLs construites ailleurs (ex: "$baseUrl/auth/login").
    final cleaned = url.trim().endsWith('/')
        ? url.trim().substring(0, url.trim().length - 1)
        : url.trim();
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, cleaned);
  }

  static String get wsUrl => _baseUrl; // socket.io se connecte sur la même origine
}
