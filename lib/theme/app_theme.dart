import 'package:flutter/material.dart';

// Palette inspirée d'un ciel dégradé : bleu profond en haut, blanc doux en bas.
// Utilisée partout pour garder une identité visuelle cohérente entre les 3 rôles.
class AppColors {
  static const skyDeep = Color(0xFF4FC3E8);
  static const skyMid = Color(0xFF8DD8ED);
  static const skyLight = Color(0xFFD6F1F7);
  static const skySoftWhite = Color(0xFFF5FCFE);

  static const ink = Color(0xFF1B3A4B); // texte principal, assez foncé pour le contraste
  static const inkMuted = Color(0xFF5C7A88);

  static const cardGlass = Color(0xE6FFFFFF); // blanc ~90% opaque, effet "verre"
  static const success = Color(0xFF34C77B);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFE85D5D);

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyDeep, skyMid, skyLight, skySoftWhite],
    stops: [0.0, 0.35, 0.7, 1.0],
  );
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.skyDeep,
        primary: AppColors.skyDeep,
        secondary: AppColors.skyMid,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.skyDeep,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Fond dégradé ciel, à placer derrière chaque écran (voir SkyScaffold ci-dessous).
class SkyBackground extends StatelessWidget {
  final Widget child;
  const SkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: child,
    );
  }
}

// Scaffold prêt à l'emploi avec le fond ciel + AppBar transparente — à utiliser
// à la place de Scaffold classique sur tous les écrans pour garder la cohérence visuelle.
class SkyScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const SkyScaffold({super.key, this.appBar, required this.body, this.floatingActionButton});

  @override
  Widget build(BuildContext context) {
    return SkyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

// Carte "verre dépoli" réutilisable : coins arrondis, ombre douce, fond quasi-blanc.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.skyDeep.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Badge de statut coloré (ex: accès ACTIVE / EXPIRED, alertes...).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
