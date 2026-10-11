import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/access_grant.dart';
import '../../models/classroom.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AccessGrantsScreen extends StatefulWidget {
  const AccessGrantsScreen({super.key});

  @override
  State<AccessGrantsScreen> createState() => _AccessGrantsScreenState();
}

class _AccessGrantsScreenState extends State<AccessGrantsScreen> {
  late final AdminService _service;
  List<AccessGrant> _grants = [];
  List<ClassRoom> _classRooms = [];
  List<AppUser> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = AdminService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final grants = await _service.getAllGrants();
    final classRooms = await _service.getClassRooms();
    final teachers = await _service.getUsersByRole(UserRole.teacher);
    setState(() {
      _grants = grants;
      _classRooms = classRooms;
      _teachers = teachers;
      _loading = false;
    });
  }

  Future<void> _revoke(AccessGrant grant) async {
    try {
      await _service.revokeAccess(grant.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _grantNewAccess() async {
    // Charge d'abord la salle sélectionnée pour connaître ses matières.
    ClassRoom? selectedClassRoom = _classRooms.isNotEmpty ? _classRooms.first : null;
    List<SubjectAssignment> availableSubjects = [];
    SubjectAssignment? selectedSubject;
    int durationHours = 2;

    if (selectedClassRoom != null) {
      final details = await _service.getClassRoomDetails(selectedClassRoom.id);
      availableSubjects = details.subjects;
      selectedSubject = availableSubjects.isNotEmpty ? availableSubjects.first : null;
    }

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Octroyer un accès'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ClassRoom>(
                  value: selectedClassRoom,
                  decoration: const InputDecoration(labelText: 'Salle'),
                  items: _classRooms.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (c) async {
                    if (c == null) return;
                    final details = await _service.getClassRoomDetails(c.id);
                    setDialogState(() {
                      selectedClassRoom = c;
                      availableSubjects = details.subjects;
                      selectedSubject = availableSubjects.isNotEmpty ? availableSubjects.first : null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (availableSubjects.isEmpty)
                  const Text('Aucune matière dans cette salle.', style: TextStyle(color: AppColors.danger))
                else
                  DropdownButtonFormField<SubjectAssignment>(
                    value: selectedSubject,
                    decoration: const InputDecoration(labelText: 'Matière (+ enseignant assigné)'),
                    items: availableSubjects
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} — ${s.teacherFirstName} ${s.teacherLastName}'),
                            ))
                        .toList(),
                    onChanged: (s) => setDialogState(() => selectedSubject = s),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: durationHours,
                  decoration: const InputDecoration(labelText: 'Durée'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 heure')),
                    DropdownMenuItem(value: 2, child: Text('2 heures')),
                    DropdownMenuItem(value: 24, child: Text('24 heures')),
                    DropdownMenuItem(value: 72, child: Text('3 jours')),
                  ],
                  onChanged: (v) => setDialogState(() => durationHours = v ?? 2),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: selectedSubject == null ? null : () => Navigator.pop(context, true),
              child: const Text('Octroyer'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selectedClassRoom != null && selectedSubject != null) {
      try {
        await _service.grantAccess(
          teacherId: selectedSubject!.teacherId,
          classRoomId: selectedClassRoom!.id,
          subjectAssignmentId: selectedSubject!.id,
          expiresAt: DateTime.now().add(Duration(hours: durationHours)),
          reason: 'saisie initiale',
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

  Color _statusColor(GrantStatus status) {
    switch (status) {
      case GrantStatus.active:
        return AppColors.success;
      case GrantStatus.expired:
        return AppColors.inkMuted;
      case GrantStatus.revoked:
        return AppColors.danger;
    }
  }

  String _statusLabel(AccessGrant g) {
    if (g.status == GrantStatus.active && !g.isCurrentlyValid) return 'Expiré';
    switch (g.status) {
      case GrantStatus.active:
        return 'Actif';
      case GrantStatus.expired:
        return 'Expiré';
      case GrantStatus.revoked:
        return 'Révoqué';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: const Text('Accès temporaires')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.skyDeep,
        onPressed: _grantNewAccess,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _grants.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aucun accès octroyé. Touchez + pour en créer un.',
                            style: TextStyle(color: AppColors.inkMuted)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 90, 16, 90),
                      itemCount: _grants.length,
                      itemBuilder: (context, index) {
                        final g = _grants[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.teacherName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${g.subjectName} · ${g.classRoomName}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                                    ],
                                  ),
                                ),
                                StatusBadge(label: _statusLabel(g), color: _statusColor(g.status)),
                                if (g.isCurrentlyValid) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.block_rounded, color: AppColors.danger, size: 20),
                                    tooltip: 'Révoquer',
                                    onPressed: () => _revoke(g),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
