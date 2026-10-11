import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'services/auth_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load(); // recharge l'adresse serveur choisie précédemment, si existante
  runApp(const SmartrackApp());
}

class SmartrackApp extends StatelessWidget {
  const SmartrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(context.read<ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Smartrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        // Point de départ toujours l'écran de login — l'auto-reconnexion via
        // token stocké (biométrie) sera ajoutée lors du développement de l'écran
        // enseignant, qui en a le plus besoin (déverrouillage rapide entre les cours).
        home: const LoginScreen(),
      ),
    );
  }
}
