import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../models/absence.dart';
import '../../models/bulletin.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../services/supervisor_service.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import '../shared/bulletin_view_screen.dart';

const List<Color> _avatarPalette = [
  Color(0xFF4FA8D6),
  Color(0xFF34A87B),
  Color(0xFFD68F3B),
  Color(0xFF8B7FC7),
  Color(0xFFD1725D),
  Color(0xFF3D9494),
];

Color _avatarColorFor(String name) {
  final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return _avatarPalette[hash % _avatarPalette.length];
}

String _initialsOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String _greetingWord() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Bonjour';
  if (hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RealtimeService _realtime;
  late final SupervisorService _supervisorService;
  List<SupervisorGradeRecord> _grades = [];
  List<AbsenceDayGroup> _absenceGroups = [];
  bool _loadingHistory = true;
  bool _loadingAbsences = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _realtime = RealtimeService(context.read<ApiService>());
    _supervisorService = SupervisorService(context.read<ApiService>());
    _realtime.connect();
    _loadHistory();
    _loadAbsences();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final grades = await _supervisorService.getAllGrades();
      setState(() {
        _grades = grades;
        _loadingHistory = false;
      });
    } catch (_) {
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadAbsences() async {
    setState(() => _loadingAbsences = true);
    try {
      final absences = await _supervisorService.getAllAbsences();
      setState(() {
        _absenceGroups = AbsenceDayGroup.groupByStudentAndDay(absences);
        _loadingAbsences = false;
      });
    } catch (_) {
      setState(() => _loadingAbsences = false);
    }
  }

  Future<void> _approve(AbsenceDayGroup group) async {
    try {
      await _supervisorService.approveJustification(studentId: group.studentId, date: group.date);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Justification approuvée pour ${group.studentName}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _loadAbsences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  void dispose() {
    _realtime.dispose();
    _tabController.dispose();
    super.dispose();
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

    return ChangeNotifierProvider.value(
      value: _realtime,
      child: SkyScaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          titleSpacing: 20,
          title: Text(
            '${_greetingWord()}, ${user?.firstName ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.inkMuted,
            indicatorColor: AppColors.skyDeep,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'Alertes'),
              Tab(text: 'Historique'),
              Tab(text: 'Absences'),
              Tab(text: 'Bulletins'),
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
        body: Padding(
          padding: const EdgeInsets.only(top: 122),
          child: TabBarView(
            controller: _tabController,
            children: [
              const _LiveFeedTab(),
              _HistoryTab(grades: _grades, loading: _loadingHistory, onRefresh: _loadHistory),
              _AbsencesTab(
                groups: _absenceGroups,
                loading: _loadingAbsences,
                onRefresh: _loadAbsences,
                onApprove: _approve,
              ),
              _BulletinsTab(supervisorService: _supervisorService),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveFeedTab extends StatelessWidget {
  const _LiveFeedTab();

  @override
  Widget build(BuildContext context) {
    final realtime = context.watch<RealtimeService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (realtime.isConnected ? AppColors.success : AppColors.danger).withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: realtime.isConnected ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  realtime.isConnected ? 'Connecté — alertes en temps réel' : 'Déconnecté',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: realtime.isConnected ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: realtime.events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none_rounded, size: 28, color: AppColors.skyDeep),
                        ),
                        const SizedBox(height: 16),
                        const Text('Aucune alerte pour le moment',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text(
                          'Toute saisie ou modification de note apparaîtra ici instantanément.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: realtime.events.length,
                  itemBuilder: (context, index) {
                    final e = realtime.events[index];
                    final isModification = e.action == 'GRADE_MODIFIED';
                    final accent = isModification ? AppColors.warning : AppColors.success;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardGlass,
                            boxShadow: [
                              BoxShadow(color: AppColors.skyDeep.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(width: 4, color: accent),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(color: accent.withOpacity(0.14), shape: BoxShape.circle),
                                          child: Icon(
                                            isModification ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                                            color: accent,
                                            size: 17,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isModification ? 'Note modifiée' : 'Note saisie',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                              ),
                                              const SizedBox(height: 3),
                                              Text('${e.studentName} — ${e.subjectName} (${e.classRoomName})',
                                                  style: const TextStyle(fontSize: 12.5)),
                                              Text('par ${e.teacherName}',
                                                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                                              if (isModification && e.oldValue != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.warning.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      '${e.oldValue!.toStringAsFixed(1)} → ${e.newValue.toStringAsFixed(1)}',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                              if (e.reason != null && e.reason!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 6),
                                                  child: Text('Motif : ${e.reason}',
                                                      style: const TextStyle(
                                                          fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.inkMuted)),
                                                ),
                                            ],
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<SupervisorGradeRecord> grades;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _HistoryTab({required this.grades, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (grades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
                child: const Icon(Icons.fact_check_outlined, size: 28, color: AppColors.skyDeep),
              ),
              const SizedBox(height: 16),
              const Text('Aucune note saisie pour le moment', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: grades.length,
        itemBuilder: (context, index) {
          final g = grades[index];
          final avatarColor = _avatarColorFor(g.studentName);
          final passed = g.value >= g.maxValue / 2;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: avatarColor.withOpacity(0.14), shape: BoxShape.circle),
                    child: Text(_initialsOf(g.studentName),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: avatarColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text('${g.subjectName} · ${g.teacherName}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                        if (g.modificationCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 12, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Text('${g.modificationCount} modification(s)',
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.warning, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: '${g.value.toStringAsFixed(1)}/${g.maxValue.toStringAsFixed(0)}',
                    color: passed ? AppColors.success : AppColors.danger,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AbsencesTab extends StatelessWidget {
  final List<AbsenceDayGroup> groups;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(AbsenceDayGroup) onApprove;

  const _AbsencesTab({
    required this.groups,
    required this.loading,
    required this.onRefresh,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    // Ce qui nécessite une action du superviseur en priorité : pas encore approuvé.
    final pending = groups.where((g) => !g.allApproved).toList();
    final other = groups.where((g) => g.allApproved).toList();

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
                child: const Icon(Icons.event_available_rounded, size: 28, color: AppColors.skyDeep),
              ),
              const SizedBox(height: 16),
              const Text('Aucune absence enregistrée pour le moment',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 17, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('En attente de votre approbation',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 25),
              child: Text(
                "L'élève a justifié en personne — approuvez pour transmettre à l'admin.",
                style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(height: 12),
            for (final g in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PendingAbsenceCard(group: g, onApprove: () => onApprove(g)),
              ),
            const SizedBox(height: 22),
          ],
          const Row(
            children: [
              Icon(Icons.list_alt_rounded, size: 17, color: AppColors.skyDeep),
              SizedBox(width: 8),
              Text('Toutes les absences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          for (final g in other)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AbsenceRow(group: g),
            ),
        ],
      ),
    );
  }
}

class _PendingAbsenceCard extends StatelessWidget {
  final AbsenceDayGroup group;
  final VoidCallback onApprove;
  const _PendingAbsenceCard({required this.group, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColorFor(group.studentName);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.warning.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: avatarColor.withOpacity(0.14), shape: BoxShape.circle),
            child: Text(_initialsOf(group.studentName),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: avatarColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('${group.date} · ${group.totalHours.toStringAsFixed(0)}h absent(es)',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            onPressed: onApprove,
            child: const Text('Approuver', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _AbsenceRow extends StatelessWidget {
  final AbsenceDayGroup group;
  const _AbsenceRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColorFor(group.studentName);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: avatarColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Text(_initialsOf(group.studentName),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: avatarColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text('${group.date} · ${group.totalHours.toStringAsFixed(0)}h',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
              ],
            ),
          ),
          StatusBadge(
            label: group.allJustified ? 'Justifiée' : 'Approuvée — en attente admin',
            color: group.allJustified ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _BulletinsTab extends StatefulWidget {
  final SupervisorService supervisorService;
  const _BulletinsTab({required this.supervisorService});

  @override
  State<_BulletinsTab> createState() => _BulletinsTabState();
}

const _terms = ['Trimestre 1', 'Trimestre 2', 'Trimestre 3'];

class _BulletinsTabState extends State<_BulletinsTab> {
  List<ClassRoom> _classRooms = [];
  ClassRoom? _selectedClassRoom;
  String _selectedTerm = _terms.first;
  List<BulletinListItem>? _results;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final classRooms = await widget.supervisorService.getClassRooms();
    setState(() {
      _classRooms = classRooms;
      _selectedClassRoom = classRooms.isNotEmpty ? classRooms.first : null;
      _loading = false;
    });
    if (_selectedClassRoom != null) _fetchResults();
  }

  Future<void> _fetchResults() async {
    if (_selectedClassRoom == null) return;
    final results = await widget.supervisorService
        .getBulletinsForClass(classRoomId: _selectedClassRoom!.id, term: _selectedTerm);
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ClassRoom>(
                  value: _selectedClassRoom,
                  decoration: const InputDecoration(labelText: 'Salle'),
                  items: _classRooms.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) {
                    setState(() {
                      _selectedClassRoom = c;
                      _results = null;
                    });
                    _fetchResults();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTerm,
                  decoration: const InputDecoration(labelText: 'Trimestre'),
                  items: _terms.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (t) {
                    setState(() {
                      _selectedTerm = t ?? _terms.first;
                      _results = null;
                    });
                    _fetchResults();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_results == null)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_results!.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
                    child: const Icon(Icons.summarize_outlined, size: 26, color: AppColors.skyDeep),
                  ),
                  const SizedBox(height: 14),
                  const Text('Aucun bulletin généré pour cette salle/trimestre.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          for (final r in _results!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BulletinResultRow(item: r, supervisorService: widget.supervisorService),
            ),
      ],
    );
  }
}

class _BulletinResultRow extends StatelessWidget {
  final BulletinListItem item;
  final SupervisorService supervisorService;
  const _BulletinResultRow({required this.item, required this.supervisorService});

  @override
  Widget build(BuildContext context) {
    final rank = item.rank;
    final isTopThree = rank != null && rank <= 3;
    final rankColor = rank == 1
        ? const Color(0xFFD4A017)
        : rank == 2
            ? const Color(0xFF9AA5AD)
            : rank == 3
                ? const Color(0xFFB08D57)
                : AppColors.skyDeep;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulletinViewScreen(
            bulletinId: item.id,
            fetchDetail: supervisorService.getBulletinDetail,
            onSign: supervisorService.signBulletin,
          ),
        ),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: rankColor.withOpacity(isTopThree ? 0.18 : 0.1), shape: BoxShape.circle),
              child: isTopThree
                  ? Icon(Icons.emoji_events_rounded, size: 16, color: rankColor)
                  : Text('${rank ?? "-"}', style: TextStyle(color: rankColor, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
            StatusBadge(
              label: '${item.average.toStringAsFixed(2)}/20',
              color: item.average >= 10 ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}