import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/absence.dart';
import '../../services/api_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

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

class AdminAbsencesScreen extends StatefulWidget {
  const AdminAbsencesScreen({super.key});

  @override
  State<AdminAbsencesScreen> createState() => _AdminAbsencesScreenState();
}

class _AdminAbsencesScreenState extends State<AdminAbsencesScreen> {
  late final AdminService _service;
  List<AbsenceDayGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = AdminService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final absences = await _service.getAllAbsences();
    setState(() {
      _groups = AbsenceDayGroup.groupByStudentAndDay(absences);
      _loading = false;
    });
  }

  Future<void> _confirm(AbsenceDayGroup group) async {
    try {
      await _service.confirmJustification(studentId: group.studentId, date: group.date);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Absence(s) justifiée(s) pour ${group.studentName}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ce que l'admin doit prioritairement traiter : approuvé par le superviseur,
    // mais pas encore confirmé — le reste est affiché en dessous, à titre informatif.
    final pending = _groups.where((g) => g.allApproved && !g.allJustified).toList();
    final other = _groups.where((g) => !(g.allApproved && !g.allJustified)).toList();

    return SkyScaffold(
      appBar: AppBar(title: const Text('Absences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
                children: [
                  if (_groups.isNotEmpty) _SummaryStrip(pending: pending.length, total: _groups.length),
                  if (_groups.isNotEmpty) const SizedBox(height: 22),
                  if (pending.isNotEmpty) ...[
                    const _SectionLabel(
                      icon: Icons.hourglass_top_rounded,
                      title: 'En attente de confirmation',
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.only(left: 26),
                      child: Text(
                        'Approuvées par le superviseur — vous pouvez confirmer la justification.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final g in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PendingCard(group: g, onConfirm: () => _confirm(g)),
                      ),
                    const SizedBox(height: 22),
                  ],
                  const _SectionLabel(
                    icon: Icons.list_alt_rounded,
                    title: 'Toutes les absences',
                    color: AppColors.skyDeep,
                  ),
                  const SizedBox(height: 12),
                  if (other.isEmpty && pending.isEmpty) const _EmptyState(),
                  for (final g in other)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AbsenceRow(group: g),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int pending;
  final int total;
  const _SummaryStrip({required this.pending, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.hourglass_top_rounded,
            value: '$pending',
            label: pending > 1 ? 'en attente' : 'en attente',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            icon: Icons.event_note_rounded,
            value: '$total',
            label: total > 1 ? 'situations' : 'situation',
            color: AppColors.skyDeep,
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionLabel({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppColors.ink)),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final AbsenceDayGroup group;
  final VoidCallback onConfirm;
  const _PendingCard({required this.group, required this.onConfirm});

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
                const SizedBox(height: 2),
                Text('${group.date} · ${group.totalHours.toStringAsFixed(0)}h absent(es)',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            onPressed: onConfirm,
            child: const Text('Confirmer', style: TextStyle(fontSize: 13)),
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
            label: group.allJustified ? 'Justifiée' : 'Non justifiée',
            color: group.allJustified ? AppColors.success : AppColors.inkMuted,
          ),
        ],
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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
              child: const Icon(Icons.event_available_rounded, size: 28, color: AppColors.skyDeep),
            ),
            const SizedBox(height: 14),
            const Text('Aucune absence enregistrée', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}