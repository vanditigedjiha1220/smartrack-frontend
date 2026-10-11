import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../models/grade.dart';
import '../../services/api_service.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';

class GradeEntryScreen extends StatefulWidget {
  final ClassRoom classRoom;
  final dynamic subject; // SubjectAssignment

  const GradeEntryScreen({super.key, required this.classRoom, required this.subject});

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

const _currentTerm = 'Trimestre 1'; // TODO: rendre sélectionnable une fois plusieurs trimestres gérés

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  late final TeacherService _service;
  List<Student> _students = [];
  Map<String, Grade> _existingGrades = {}; // studentId -> Grade déjà saisie
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  String? _error;
  final Set<String> _saving = {};

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
      final details = await _service.getClassRoomDetails(widget.classRoom.id);
      final grades = await _service.getMyGrades(widget.classRoom.id, widget.subject.id as String);
      final gradesByStudent = {for (final g in grades) g.studentId: g};

      for (final student in details.students) {
        _controllers[student.id] = TextEditingController(
          text: gradesByStudent[student.id]?.value.toString() ?? '',
        );
      }

      setState(() {
        _students = details.students;
        _existingGrades = gradesByStudent;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(Student student) async {
    final controller = _controllers[student.id]!;
    final rawValue = controller.text.trim();
    if (rawValue.isEmpty) return;

    final value = double.tryParse(rawValue.replaceAll(',', '.'));
    if (value == null || value < 0 || value > 20) {
      _showSnack('La note doit être un nombre entre 0 et 20', AppColors.danger);
      return;
    }

    final existing = _existingGrades[student.id];

    if (existing != null && existing.value == value) {
      return; // rien n'a changé, pas besoin d'appeler le serveur
    }

    setState(() => _saving.add(student.id));

    try {
      if (existing == null) {
        // Première saisie — pas de motif requis.
        await _service.createGrade(
          studentId: student.id,
          classRoomId: widget.classRoom.id,
          subjectAssignmentId: widget.subject.id as String,
          term: _currentTerm,
          value: value,
        );
        _showSnack('Note enregistrée pour ${student.fullName}', AppColors.success);
        await _load();
      } else {
        // Modification d'une note déjà saisie — motif OBLIGATOIRE, demandé via une boîte de dialogue.
        final reason = await _askReason(context, existing.value, value);
        if (reason == null || reason.trim().isEmpty) {
          controller.text = existing.value.toString(); // annule visuellement le changement
          setState(() => _saving.remove(student.id));
          return;
        }
        await _service.modifyGrade(gradeId: existing.id, newValue: value, reason: reason);
        _showSnack('Note modifiée pour ${student.fullName}', AppColors.success);
        await _load();
      }
    } catch (e) {
      _showSnack(e.toString(), AppColors.danger);
    } finally {
      if (mounted) setState(() => _saving.remove(student.id));
    }
  }

  Future<String?> _askReason(BuildContext context, double oldValue, double newValue) {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Motif de la modification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note : ${oldValue.toStringAsFixed(1)} → ${newValue.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ce motif sera envoyé immédiatement aux superviseurs, avec la note avant/après.',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'ex: erreur de saisie, note oubliée...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: Text('${widget.subject.name} — ${widget.classRoom.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 90, 16, 16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final hasExisting = _existingGrades.containsKey(student.id);
                    final isSaving = _saving.contains(student.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(student.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(student.matricule,
                                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: _controllers[student.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '/20',
                                  isDense: true,
                                  filled: true,
                                  fillColor: hasExisting
                                      ? AppColors.skyLight
                                      : Colors.white.withOpacity(0.7),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                onSubmitted: (_) => _submit(student),
                              ),
                            ),
                            const SizedBox(width: 8),
                            isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      hasExisting ? Icons.check_circle : Icons.save_outlined,
                                      color: hasExisting ? AppColors.success : AppColors.skyDeep,
                                    ),
                                    onPressed: () => _submit(student),
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