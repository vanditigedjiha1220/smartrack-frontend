import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

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

String _initialsOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class ClassroomsScreen extends StatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  State<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends State<ClassroomsScreen> {
  late final AdminService _service;
  List<ClassRoom> _classRooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = AdminService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classRooms = await _service.getClassRooms();
      setState(() {
        _classRooms = classRooms;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createClassRoom() async {
    final nameController = TextEditingController();
    final levelController = TextEditingController();
    final yearController = TextEditingController(text: '2026-2027');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle salle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom (ex: 3e A)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: levelController,
                decoration: const InputDecoration(labelText: 'Niveau (ex: 3e)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Année scolaire'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );

    if (created == true && nameController.text.isNotEmpty) {
      try {
        await _service.createClassRoom(
          name: nameController.text,
          level: levelController.text,
          year: yearController.text,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: const Text('Salles & matières')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createClassRoom,
        backgroundColor: AppColors.skyDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _classRooms.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 96, 16, 90),
                          itemCount: _classRooms.length,
                          itemBuilder: (context, index) {
                            final c = _classRooms[index];
                            final accent = _accentFor(c.name);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ClassroomDetailScreen(classRoomId: c.id),
                                        ),
                                      );
                                      _load();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.cardGlass,
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppColors.skyDeep.withOpacity(0.12),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8)),
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
                                                      width: 48,
                                                      height: 48,
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: accent.withOpacity(0.13),
                                                        borderRadius: BorderRadius.circular(13),
                                                      ),
                                                      child: Icon(Icons.meeting_room_rounded, color: accent, size: 22),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(c.name,
                                                              style: const TextStyle(
                                                                  fontWeight: FontWeight.w700, fontSize: 16)),
                                                          Text('${c.level} · ${c.year}',
                                                              style: const TextStyle(
                                                                  color: AppColors.inkMuted, fontSize: 12.5)),
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
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
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
              child: const Icon(Icons.meeting_room_outlined, size: 32, color: AppColors.skyDeep),
            ),
            const SizedBox(height: 16),
            const Text('Aucune salle pour le moment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Touchez le bouton + pour créer la première.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// --- Détail d'une salle : matières assignées + élèves ---

class ClassroomDetailScreen extends StatefulWidget {
  final String classRoomId;
  const ClassroomDetailScreen({super.key, required this.classRoomId});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> with SingleTickerProviderStateMixin {
  late final AdminService _service;
  ClassRoom? _classRoom;
  List<AppUser> _teachers = [];
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service = AdminService(context.read<ApiService>());
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final classRoom = await _service.getClassRoomDetails(widget.classRoomId);
    final teachers = await _service.getUsersByRole(UserRole.teacher);
    setState(() {
      _classRoom = classRoom;
      _teachers = teachers;
      _loading = false;
    });
  }

  Future<void> _addSubject() async {
    final nameController = TextEditingController();
    final coefController = TextEditingController(text: '1');
    String? selectedTeacherId = _teachers.isNotEmpty ? _teachers.first.id : null;
    SubjectCategory selectedCategory = SubjectCategory.autre;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle matière'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom (ex: Mathématiques)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SubjectCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: SubjectCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(subjectCategoryLabel(c))))
                      .toList(),
                  onChanged: (c) => setDialogState(() => selectedCategory = c ?? SubjectCategory.autre),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coefController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Coefficient'),
                ),
                const SizedBox(height: 12),
                if (_teachers.isEmpty)
                  const Text("Aucun enseignant créé. Créez-en un d'abord dans Comptes.",
                      style: TextStyle(color: AppColors.danger, fontSize: 12))
                else
                  DropdownButtonFormField<String>(
                    value: selectedTeacherId,
                    decoration: const InputDecoration(labelText: 'Enseignant'),
                    items: _teachers
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedTeacherId = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: _teachers.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameController.text.isNotEmpty && selectedTeacherId != null) {
      try {
        await _service.addSubject(
          classRoomId: widget.classRoomId,
          name: nameController.text,
          category: selectedCategory,
          coefficient: double.tryParse(coefController.text) ?? 1,
          teacherId: selectedTeacherId!,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  Future<void> _addStudent() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final matriculeController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvel élève'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 12),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 12),
              TextField(controller: matriculeController, decoration: const InputDecoration(labelText: 'Matricule')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
        ],
      ),
    );

    if (ok == true && firstNameController.text.isNotEmpty && matriculeController.text.isNotEmpty) {
      try {
        await _service.addStudent(
          classRoomId: widget.classRoomId,
          firstName: firstNameController.text,
          lastName: lastNameController.text,
          matricule: matriculeController.text,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  Future<void> _setPrincipalTeacher() async {
    if (_classRoom == null || _classRoom!.subjects.isEmpty) return;

    // Seuls les enseignants déjà assignés à une matière de cette salle sont éligibles.
    final eligibleTeacherIds = _classRoom!.subjects.map((s) => s.teacherId).toSet();
    final eligibleTeachers = _teachers.where((t) => eligibleTeacherIds.contains(t.id)).toList();

    String? selected = _classRoom!.principalTeacherId ?? (eligibleTeachers.isNotEmpty ? eligibleTeachers.first.id : null);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Professeur principal'),
          content: eligibleTeachers.isEmpty
              ? const Text("Aucun enseignant n'est encore assigné à une matière de cette salle.")
              : DropdownButtonFormField<String>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Enseignant'),
                  items: eligibleTeachers
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selected = v),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: eligibleTeachers.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Définir'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selected != null) {
      try {
        await _service.setPrincipalTeacher(classRoomId: widget.classRoomId, teacherId: selected!);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(
        title: Text(_classRoom?.name ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            tooltip: 'Professeur principal',
            onPressed: _setPrincipalTeacher,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.skyDeep,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          tabs: const [Tab(text: 'Matières'), Tab(text: 'Élèves')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.skyDeep,
        onPressed: () => _tabController.index == 0 ? _addSubject() : _addStudent(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.only(top: 130),
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    children: [
                      if (_classRoom?.principalTeacherName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('Professeur principal · ${_classRoom!.principalTeacherName}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if ((_classRoom?.subjects ?? []).isEmpty)
                        const _MinimalEmpty(icon: Icons.menu_book_outlined, text: 'Aucune matière assignée.'),
                      for (final s in _classRoom?.subjects ?? [])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SubjectRow(subject: s),
                        ),
                    ],
                  ),
                  (_classRoom?.students.isEmpty ?? true)
                      ? const _MinimalEmpty(icon: Icons.groups_outlined, text: 'Aucun élève inscrit.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: _classRoom?.students.length ?? 0,
                          itemBuilder: (context, index) {
                            final s = _classRoom!.students[index];
                            final accent = _accentFor(s.fullName);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: accent.withOpacity(0.13), shape: BoxShape.circle),
                                      child: Text(_initialsOf(s.fullName),
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: accent)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.skyLight,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(s.matricule,
                                          style: const TextStyle(fontSize: 11, color: AppColors.skyDeep, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final dynamic subject; // SubjectAssignment
  const _SubjectRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(subject.name as String);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withOpacity(0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.menu_book_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(subject.name as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    StatusBadge(label: subjectCategoryLabel(subject.category), color: AppColors.skyMid),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${subject.teacherFirstName} ${subject.teacherLastName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ],
            ),
          ),
          StatusBadge(label: 'coef. ${(subject.coefficient as double).toStringAsFixed(0)}', color: AppColors.skyDeep),
        ],
      ),
    );
  }
}

class _MinimalEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MinimalEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.inkMuted.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
        ],
      ),
    );
  }
}