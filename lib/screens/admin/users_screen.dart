import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
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

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late final AdminService _service;
  late final TabController _tabController;
  List<AppUser> _teachers = [];
  List<AppUser> _supervisors = [];
  bool _loading = true;

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
    final teachers = await _service.getUsersByRole(UserRole.teacher);
    final supervisors = await _service.getUsersByRole(UserRole.supervisor);
    setState(() {
      _teachers = teachers;
      _supervisors = supervisors;
      _loading = false;
    });
  }

  Future<void> _createAccount() async {
    final role = _tabController.index == 0 ? UserRole.teacher : UserRole.supervisor;
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(role == UserRole.teacher ? 'Nouvel enseignant' : 'Nouveau superviseur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 12),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe temporaire (min. 6 caractères)'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.skyLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.skyDeep),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "L'intéressé(e) devra le remplacer dès sa première connexion.",
                        style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                      ),
                    ),
                  ],
                ),
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

    if (ok == true &&
        firstNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        passwordController.text.length >= 6) {
      try {
        await _service.createUser(
          firstName: firstNameController.text,
          lastName: lastNameController.text,
          email: emailController.text,
          password: passwordController.text,
          role: role,
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

  Widget _buildList(List<AppUser> users, IconData icon) {
    if (users.isEmpty) {
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
                child: Icon(icon, size: 28, color: AppColors.skyDeep),
              ),
              const SizedBox(height: 14),
              const Text('Aucun compte pour le moment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Touchez le bouton + pour en créer un.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final avatarColor = _avatarColorFor(u.fullName);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: avatarColor.withOpacity(0.14), shape: BoxShape.circle),
                  child: Text(_initialsOf(u.fullName),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: avatarColor)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 1),
                      Text(u.email, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                Icon(icon, size: 16, color: AppColors.inkMuted.withOpacity(0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(
        title: const Text('Comptes'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.skyDeep,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          tabs: const [Tab(text: 'Enseignants'), Tab(text: 'Superviseurs')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.skyDeep,
        onPressed: _createAccount,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.only(top: 130),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_teachers, Icons.school_rounded),
                  _buildList(_supervisors, Icons.visibility_rounded),
                ],
              ),
            ),
    );
  }
}