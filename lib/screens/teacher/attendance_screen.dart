import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../services/api_service.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';

const _terms = ['Trimestre 1', 'Trimestre 2', 'Trimestre 3'];

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

class AttendanceScreen extends StatefulWidget {
  final ClassRoom classRoom;
  final dynamic subject; // SubjectAssignment

  const AttendanceScreen({super.key, required this.classRoom, required this.subject});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final TeacherService _service;
  List<Student> _students = [];
  final Set<String> _absentIds = {};
  bool _loading = true;
  bool _submitting = false;
  String _term = _terms.first;
  DateTime _date = DateTime.now();
  double _hours = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _service = TeacherService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final details = await _service.getClassRoomDetails(widget.classRoom.id);
    setState(() {
      _students = details.students;
      _loading = false;
    });
  }

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _service.recordAttendance(
        classRoomId: widget.classRoom.id,
        subjectAssignmentId: widget.subject.id as String,
        term: _term,
        date: _dateString,
        hours: _hours,
        absentStudentIds: _absentIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_absentIds.isEmpty
              ? 'Appel enregistré — aucun absent'
              : 'Appel enregistré — ${_absentIds.length} absent(s)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _students
        : _students.where((s) => s.fullName.toLowerCase().contains(_search.toLowerCase())).toList();

    return SkyScaffold(
      appBar: AppBar(title: Text("Appel — ${widget.subject.name}")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 90),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _term,
                                decoration: const InputDecoration(labelText: 'Trimestre'),
                                items: _terms.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (t) => setState(() => _term = t ?? _terms.first),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _hours.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Heures de la séance'),
                                onChanged: (v) => _hours = double.tryParse(v) ?? 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date du cours'),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.skyDeep),
                                const SizedBox(width: 8),
                                Text(_dateString, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Rechercher un élève',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _AbsentCounter(count: _absentIds.length, total: _students.length),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: AppColors.inkMuted.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Cochez les élèves absents — envoyé immédiatement au superviseur.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final isAbsent = _absentIds.contains(student.id);
                      final avatarColor = _avatarColorFor(student.fullName);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() {
                            isAbsent ? _absentIds.remove(student.id) : _absentIds.add(student.id);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isAbsent ? AppColors.danger.withOpacity(0.06) : AppColors.cardGlass,
                              borderRadius: BorderRadius.circular(16),
                              border: isAbsent ? Border.all(color: AppColors.danger.withOpacity(0.25)) : null,
                              boxShadow: isAbsent
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: AppColors.skyDeep.withOpacity(0.1),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isAbsent ? AppColors.inkMuted.withOpacity(0.15) : avatarColor.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _initialsOf(student.fullName),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: isAbsent ? AppColors.inkMuted : avatarColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(student.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isAbsent ? AppColors.danger : AppColors.ink,
                                        decoration: isAbsent ? TextDecoration.lineThrough : null,
                                        decorationColor: AppColors.danger.withOpacity(0.4),
                                      )),
                                ),
                                Checkbox(
                                  value: isAbsent,
                                  activeColor: AppColors.danger,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (v) => setState(() {
                                    v == true ? _absentIds.add(student.id) : _absentIds.remove(student.id);
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(color: AppColors.skyDeep.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_submitting ? 'Envoi en cours…' : "Valider l'appel"),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AbsentCounter extends StatelessWidget {
  final int count;
  final int total;
  const _AbsentCounter({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = count == 0 ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(
        '$count/$total',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}