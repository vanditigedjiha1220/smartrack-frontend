import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/classroom.dart';
import '../../models/bulletin.dart';
import '../../services/api_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../shared/bulletin_view_screen.dart';

const _terms = ['Trimestre 1', 'Trimestre 2', 'Trimestre 3'];

class BulletinsScreen extends StatefulWidget {
  const BulletinsScreen({super.key});

  @override
  State<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends State<BulletinsScreen> {
  late final AdminService _service;
  List<ClassRoom> _classRooms = [];
  ClassRoom? _selectedClassRoom;
  String _selectedTerm = _terms.first;
  List<BulletinListItem>? _results;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = AdminService(context.read<ApiService>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final classRooms = await _service.getClassRooms();
    setState(() {
      _classRooms = classRooms;
      _selectedClassRoom = classRooms.isNotEmpty ? classRooms.first : null;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    if (_selectedClassRoom == null) return;
    setState(() {
      _generating = true;
      _error = null;
      _results = null;
    });
    try {
      await _service.generateBulletins(classRoomId: _selectedClassRoom!.id, term: _selectedTerm);
      // La réponse de génération n'inclut pas les id — on recharge la liste
      // complète (avec id) pour pouvoir ouvrir chaque bulletin ensuite.
      final list = await _service.listBulletins(classRoomId: _selectedClassRoom!.id, term: _selectedTerm);
      setState(() {
        _results = list;
        _generating = false;
      });
    } catch (e) {
      // Le serveur renvoie la liste des couples élève/matière manquants — jamais de valeur de note.
      final message = e.toString();
      setState(() {
        _error = message;
        _generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: const Text('Bulletins')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.skyLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.summarize_rounded, color: AppColors.skyDeep, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Générer les bulletins',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.skyLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, size: 15, color: AppColors.skyDeep),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Le calcul se fait entièrement côté serveur. Vous recevez uniquement '
                                'les moyennes et le classement — jamais la grille de notes brute.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<ClassRoom>(
                        value: _selectedClassRoom,
                        decoration: const InputDecoration(labelText: 'Salle'),
                        items: _classRooms.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (c) => setState(() => _selectedClassRoom = c),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTerm,
                        decoration: const InputDecoration(labelText: 'Trimestre'),
                        items: _terms.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (t) => setState(() => _selectedTerm = t ?? _terms.first),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _generating || _selectedClassRoom == null ? null : _generate,
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: Text(_generating ? 'Génération en cours…' : 'Générer les bulletins'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) _ErrorBanner(message: _error!),
                if (_results != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.leaderboard_rounded, size: 17, color: AppColors.skyDeep),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${_selectedClassRoom?.name} · $_selectedTerm',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 25),
                    child: Text('Touchez un élève pour voir le bulletin complet.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                  ),
                  const SizedBox(height: 12),
                  for (final r in _results!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ResultRow(item: r, service: _service),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final BulletinListItem item;
  final AdminService service;
  const _ResultRow({required this.item, required this.service});

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
            fetchDetail: service.getBulletinDetail,
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
              decoration: BoxDecoration(
                color: rankColor.withOpacity(isTopThree ? 0.18 : 0.1),
                shape: BoxShape.circle,
              ),
              child: isTopThree
                  ? Icon(Icons.emoji_events_rounded, size: 16, color: rankColor)
                  : Text('${rank ?? "-"}', style: TextStyle(color: rankColor, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.contains('Notes manquantes')
                  ? 'Certaines notes sont manquantes pour cette salle — la génération '
                      'a été annulée. Relancez les enseignants concernés.'
                  : message,
              style: const TextStyle(color: AppColors.ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}