import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'classrooms_screen.dart';
import 'users_screen.dart';
import 'access_grants_screen.dart';
import 'bulletins_screen.dart';
import 'absences_screen.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String _greetingWord() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Bonjour';
  if (hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

String _todayLabel() {
  final now = DateTime.now();
  final wd = _weekdays[now.weekday - 1];
  final capitalized = wd[0].toUpperCase() + wd.substring(1);
  return '$capitalized ${now.day} ${_months[now.month - 1]}';
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final tiles = [
      _DashboardTile(
        icon: Icons.meeting_room_rounded,
        label: 'Salles & matières',
        subtitle: 'Créer des salles, assigner matières et enseignants',
        accent: const Color(0xFF4FA8D6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassroomsScreen())),
      ),
      _DashboardTile(
        icon: Icons.people_alt_rounded,
        label: 'Comptes',
        subtitle: 'Créer des comptes enseignants et superviseurs',
        accent: const Color(0xFF8B7FC7),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsersScreen())),
      ),
      _DashboardTile(
        icon: Icons.lock_clock_rounded,
        label: 'Accès temporaires',
        subtitle: "Octroyer ou révoquer l'accès des enseignants",
        accent: const Color(0xFFD68F3B),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccessGrantsScreen())),
      ),
      _DashboardTile(
        icon: Icons.event_busy_rounded,
        label: 'Absences',
        subtitle: 'Confirmer les justifications approuvées par le superviseur',
        accent: const Color(0xFFD1725D),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAbsencesScreen())),
      ),
      _DashboardTile(
        icon: Icons.summarize_rounded,
        label: 'Bulletins',
        subtitle: 'Générer les bulletins — résultats agrégés uniquement',
        accent: const Color(0xFF34A87B),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BulletinsScreen())),
      ),
    ];

    return SkyScaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_greetingWord()}, ${user?.firstName ?? ''}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              _todayLabel(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.white.withOpacity(0.6),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                color: AppColors.inkMuted,
                tooltip: 'Se déconnecter',
                onPressed: () => _logout(context),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 96, 16, 20),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Administration',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.inkMuted, letterSpacing: 0.3)),
          ),
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardGlass,
              boxShadow: [
                BoxShadow(color: AppColors.skyDeep.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: accent.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                            child: Icon(icon, color: accent, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                                const SizedBox(height: 2),
                                Text(subtitle, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}