import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../models/access_grant.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'grade_entry_screen.dart';
import 'attendance_screen.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

const List<Color> _accentPalette = [
  Color(0xFF4FA8D6),
  Color(0xFF34A87B),
  Color(0xFFD68F3B),
  Color(0xFF8B7FC7),
  Color(0xFFD1725D),
  Color(0xFF3D9494),
];

Color _accentFor(String key) {
  final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
  return _accentPalette[hash % _accentPalette.length];
}

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

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late final TeacherService _service;
  List<ClassRoom> _classRooms = [];
  List<AccessGrant> _grants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = TeacherService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classRooms = await _service.getAllClassRooms();
      final grants = await _service.getMyActiveGrants();
      setState(() {
        _classRooms = classRooms;
        _grants = grants;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _requestAccess(ClassRoom classRoom, dynamic subject) async {
    try {
      await _service.requestAccess(classRoom.id, subject.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Demande envoyée à l'administrateur"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  AccessGrant? _grantFor(String classRoomId, String subjectId) {
    try {
      return _grants.firstWhere(
        (g) => g.classRoomId == classRoomId && g.subjectAssignmentId == subjectId && g.isCurrentlyValid,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    // Ne garder que les matières où CET enseignant est assigné — la structure
    // complète de toutes les salles est lisible, mais on filtre côté écran
    // pour ne présenter que ce qui le concerne.
    final myAssignments = <(ClassRoom, dynamic)>[];
    for (final c in _classRooms) {
      for (final s in c.subjects) {
        if (s.teacherId == user?.id) myAssignments.add((c, s));
      }
    }

    final activeCount = myAssignments.where((a) => _grantFor(a.$1.id, a.$2.id as String) != null).length;

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
                onPressed: _logout,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : myAssignments.isEmpty
                    ? const _EmptyView()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 96, 16, 20),
                        children: [
                          _SummaryStrip(total: myAssignments.length, active: activeCount),
                          const SizedBox(height: 18),
                          for (int i = 0; i < myAssignments.length; i++) ...[
                            _AssignmentCard(
                              classRoom: myAssignments[i].$1,
                              subject: myAssignments[i].$2,
                              grant: _grantFor(myAssignments[i].$1.id, myAssignments[i].$2.id as String),
                              onRequestAccess: () => _requestAccess(myAssignments[i].$1, myAssignments[i].$2),
                              onTakeAttendance: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceScreen(
                                      classRoom: myAssignments[i].$1,
                                      subject: myAssignments[i].$2,
                                    ),
                                  ),
                                );
                              },
                              onEnterGrades: _grantFor(myAssignments[i].$1.id, myAssignments[i].$2.id as String) == null
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GradeEntryScreen(
                                            classRoom: myAssignments[i].$1,
                                            subject: myAssignments[i].$2,
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                            ),
                            if (i != myAssignments.length - 1) const SizedBox(height: 14),
                          ],
                        ],
                      ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int active;
  const _SummaryStrip({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.menu_book_rounded,
            value: '$total',
            label: total > 1 ? 'matières' : 'matière',
            color: AppColors.skyDeep,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            icon: Icons.lock_open_rounded,
            value: '$active',
            label: active > 1 ? 'accès actifs' : 'accès actif',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink, height: 1)),
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final ClassRoom classRoom;
  final dynamic subject;
  final AccessGrant? grant;
  final VoidCallback onRequestAccess;
  final VoidCallback onTakeAttendance;
  final VoidCallback? onEnterGrades;

  const _AssignmentCard({
    required this.classRoom,
    required this.subject,
    required this.grant,
    required this.onRequestAccess,
    required this.onTakeAttendance,
    required this.onEnterGrades,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(subject.name as String);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardGlass,
          boxShadow: [
            BoxShadow(color: AppColors.skyDeep.withOpacity(0.13), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(subject.name as String,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                                const SizedBox(height: 2),
                                Text(
                                  '${classRoom.name} · coefficient ${(subject.coefficient as double).toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onTakeAttendance,
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text("Faire l'appel"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (grant != null) ...[
                        Row(
                          children: [
                            const StatusBadge(label: 'Accès actif', color: AppColors.success),
                            const SizedBox(width: 8),
                            _RemainingChip(expiresAt: grant!.expiresAt),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onEnterGrades,
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text('Saisir les notes'),
                          ),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.skyLight,
                              foregroundColor: AppColors.skyDeep,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: onRequestAccess,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text("Demander un accès pour les notes"),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemainingChip extends StatelessWidget {
  final DateTime expiresAt;
  const _RemainingChip({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final urgent = remaining.inMinutes < 30;
    final color = urgent ? AppColors.warning : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            hours > 0 ? 'Expire dans ${hours}h${minutes}min' : 'Expire dans ${minutes}min',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
              child: const Icon(Icons.inbox_rounded, size: 32, color: AppColors.skyDeep),
            ),
            const SizedBox(height: 18),
            const Text(
              "Aucune matière assignée pour l'instant",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              "Contactez votre administrateur pour être rattaché à une classe.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.danger),
            ),
            const SizedBox(height: 18),
            const Text('Connexion au serveur impossible',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}