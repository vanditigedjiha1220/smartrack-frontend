import 'package:flutter/material.dart';
import '../../models/bulletin.dart';
import '../../theme/app_theme.dart';

class BulletinViewScreen extends StatefulWidget {
  final String bulletinId;
  final Future<BulletinDetail> Function(String bulletinId) fetchDetail;
  // Fourni uniquement côté superviseur — null côté admin (lecture seule).
  final Future<void> Function(String bulletinId, String comment)? onSign;

  const BulletinViewScreen({
    super.key,
    required this.bulletinId,
    required this.fetchDetail,
    this.onSign,
  });

  @override
  State<BulletinViewScreen> createState() => _BulletinViewScreenState();
}

class _BulletinViewScreenState extends State<BulletinViewScreen> {
  BulletinDetail? _bulletin;
  bool _loading = true;
  bool _signing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail = await widget.fetchDetail(widget.bulletinId);
    setState(() {
      _bulletin = detail;
      _loading = false;
    });
  }

  Future<void> _sign() async {
    if (widget.onSign == null || _bulletin == null) return;
    final commentController = TextEditingController(text: _bulletin!.supervisorComment ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Signer le bulletin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Le mot ci-dessous a été généré automatiquement selon la moyenne. '
                'Vous pouvez le modifier avant de signer.',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mot du superviseur'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Signer')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _signing = true);
    try {
      await widget.onSign!(widget.bulletinId, commentController.text);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: const Text('Bulletin')),
      body: _loading || _bulletin == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
              children: [
                _BulletinDocument(bulletin: _bulletin!),
                const SizedBox(height: 20),
                if (widget.onSign != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _bulletin!.isSigned || _signing ? null : _sign,
                      icon: _signing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(_bulletin!.isSigned ? Icons.check_circle_rounded : Icons.draw_rounded),
                      label: Text(_bulletin!.isSigned ? 'Déjà signé' : 'Signer ce bulletin'),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mentions et couleurs selon la moyenne — logique purement visuelle, calquée
// sur les usages scolaires classiques (aucun impact sur les données réelles).
// ---------------------------------------------------------------------------
class _Mention {
  final String label;
  final Color color;
  const _Mention(this.label, this.color);
}

_Mention _mentionFor(double average) {
  if (average >= 16) return const _Mention('Excellent', Color(0xFF2E9E6B));
  if (average >= 14) return const _Mention('Très bien', AppColors.success);
  if (average >= 12) return const _Mention('Bien', Color(0xFF4FA8D6));
  if (average >= 10) return const _Mention('Assez bien', AppColors.warning);
  return const _Mention('Insuffisant', AppColors.danger);
}

String _appreciationForGrade(double grade) {
  if (grade >= 16) return 'Excellent';
  if (grade >= 14) return 'Très bien';
  if (grade >= 12) return 'Bien';
  if (grade >= 10) return 'Assez bien';
  return 'Insuffisant';
}

String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Le "document" — mis en page pour ressembler à un bulletin officiel, avec une
// touche douce (dégradés, coins arrondis, accents de couleur discrets).
// ---------------------------------------------------------------------------
class _BulletinDocument extends StatelessWidget {
  final BulletinDetail bulletin;
  const _BulletinDocument({required this.bulletin});

  @override
  Widget build(BuildContext context) {
    final mention = _mentionFor(bulletin.average);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.skyMid.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.skyDeep.withOpacity(0.16), blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(bulletin: bulletin),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IdentityAndAverage(bulletin: bulletin, mention: mention),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StatusBadge(label: 'Rang ${bulletin.rank}', color: AppColors.skyDeep),
                    const SizedBox(width: 8),
                    StatusBadge(label: mention.label, color: mention.color),
                    const SizedBox(width: 8),
                    if (bulletin.isSigned)
                      const StatusBadge(label: 'Signé', color: AppColors.success)
                    else
                      const StatusBadge(label: 'En attente de signature', color: AppColors.warning),
                  ],
                ),
                const _SoftDivider(),
                const _SectionTitle(icon: Icons.menu_book_rounded, title: 'Résultats par matière'),
                const SizedBox(height: 12),
                _SubjectsTable(details: bulletin.subjectDetails),
                const _SoftDivider(),
                const _SectionTitle(icon: Icons.event_available_rounded, title: 'Assiduité'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _AbsenceStat(
                      icon: Icons.schedule_rounded,
                      label: 'Total',
                      hours: bulletin.totalAbsenceHours,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 10),
                    _AbsenceStat(
                      icon: Icons.check_circle_rounded,
                      label: 'Justifiées',
                      hours: bulletin.justifiedAbsenceHours,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _AbsenceStat(
                      icon: Icons.cancel_rounded,
                      label: 'Non justifiées',
                      hours: bulletin.unjustifiedAbsenceHours,
                      color: AppColors.danger,
                    ),
                  ],
                ),
                const _SoftDivider(),
                const _SectionTitle(icon: Icons.rate_review_rounded, title: 'Appréciation du superviseur'),
                const SizedBox(height: 10),
                _AppreciationCard(comment: bulletin.supervisorComment),
                const SizedBox(height: 20),
                _SignatureBlock(bulletin: bulletin),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- En-tête établissement --------------------------------------------------
class _Header extends StatelessWidget {
  final BulletinDetail bulletin;
  const _Header({required this.bulletin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: const BoxDecoration(gradient: AppColors.gradient),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.4),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            bulletin.schoolName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'BULLETIN — ${bulletin.term.toUpperCase()}',
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Identité élève + moyenne circulaire ------------------------------------
class _IdentityAndAverage extends StatelessWidget {
  final BulletinDetail bulletin;
  final _Mention mention;
  const _IdentityAndAverage({required this.bulletin, required this.mention});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(bulletin.studentName),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bulletin.studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
              const SizedBox(height: 2),
              Text(bulletin.classRoomName, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
              if (bulletin.principalTeacherName != null) ...[
                const SizedBox(height: 1),
                Text('Professeur principal · ${bulletin.principalTeacherName}',
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 11.5)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mention.color.withOpacity(0.10),
            border: Border.all(color: mention.color.withOpacity(0.55), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(bulletin.average.toStringAsFixed(2),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: mention.color, height: 1)),
              const Text('/20', style: TextStyle(color: AppColors.inkMuted, fontSize: 9.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.skyDeep),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink)),
      ],
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.skyLight)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: AppColors.skyMid, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 1, color: AppColors.skyLight)),
        ],
      ),
    );
  }
}

// -- Tableau des matières -----------------------------------------------
class _SubjectsTable extends StatelessWidget {
  final List<BulletinSubjectDetail> details;
  const _SubjectsTable({required this.details});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            color: AppColors.skyLight,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Matière', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Note', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Coef.', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Appréciation', style: _headerStyle)),
              ],
            ),
          ),
          for (int i = 0; i < details.length; i++) _SubjectRow(detail: details[i], alt: i.isOdd),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.ink);
}

class _SubjectRow extends StatelessWidget {
  final BulletinSubjectDetail detail;
  final bool alt;
  const _SubjectRow({required this.detail, required this.alt});

  @override
  Widget build(BuildContext context) {
    final grade = detail.grade;
    final gradeColor = grade >= 10 ? AppColors.success : AppColors.danger;

    return Container(
      color: alt ? AppColors.skySoftWhite : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(detail.subjectName, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Text(grade.toStringAsFixed(1),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gradeColor)),
          ),
          Expanded(flex: 2, child: Text(detail.coefficient.toStringAsFixed(0), style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 3,
            child: Text(_appreciationForGrade(grade),
                style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}

// -- Assiduité ---------------------------------------------------------
class _AbsenceStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double hours;
  final Color color;
  const _AbsenceStat({required this.icon, required this.label, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text('${hours.toStringAsFixed(0)}h',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

// -- Appréciation --------------------------------------------------------
class _AppreciationCard extends StatelessWidget {
  final String? comment;
  const _AppreciationCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.skyLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.skyMid.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.skyDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (comment == null || comment!.trim().isEmpty) ? 'Aucune appréciation pour le moment.' : comment!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: AppColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Signature ----------------------------------------------------------
class _SignatureBlock extends StatelessWidget {
  final BulletinDetail bulletin;
  const _SignatureBlock({required this.bulletin});

  @override
  Widget build(BuildContext context) {
    if (!bulletin.isSigned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inkMuted.withOpacity(0.3), style: BorderStyle.solid),
        ),
        child: const Center(
          child: Text('En attente de signature du superviseur',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12, fontStyle: FontStyle.italic)),
        ),
      );
    }

    final signedAt = bulletin.signedAt!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bulletin certifié',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.ink)),
                Text('Signé par ${bulletin.signedByName}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
              ],
            ),
          ),
          Text(
            '${_twoDigits(signedAt.day)}/${_twoDigits(signedAt.month)}/${signedAt.year}',
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}