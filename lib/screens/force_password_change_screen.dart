import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'supervisor/supervisor_home_screen.dart';

// Écran BLOQUANT affiché juste après une connexion avec un mot de passe encore
// marqué "temporaire" (mustChangePassword = true côté serveur) — que ce soit un
// compte créé par l'admin (enseignant, superviseur) OU le compte admin lui-même
// via seed.ts. Pas de bouton retour, pas de moyen de le contourner : le serveur
// refuse de toute façon tout autre appel tant que ce changement n'est pas fait
// (voir JwtAuthGuard côté backend).
class ForcePasswordChangeScreen extends StatefulWidget {
  final String temporaryPassword;

  const ForcePasswordChangeScreen({super.key, required this.temporaryPassword});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(
      currentPassword: widget.temporaryPassword,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmController.text,
    );

    if (!mounted) return;

    if (success) {
      _navigateByRole(auth.currentUser!.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'Erreur lors du changement de mot de passe'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _navigateByRole(UserRole role) {
    final destination = switch (role) {
      UserRole.admin => const AdminHomeScreen(),
      UserRole.teacher => const TeacherHomeScreen(),
      UserRole.supervisor => const SupervisorHomeScreen(),
    };

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: false, // aucun retour possible tant que le mot de passe n'est pas changé
      child: SkyBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.85),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.skyDeep.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.skyDeep),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sécurisez votre compte',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ce compte utilise encore un mot de passe temporaire ou par défaut. '
                        'Choisissez-en un nouveau, connu de vous seul, avant de continuer.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      GlassCard(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                decoration: InputDecoration(
                                  labelText: 'Nouveau mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Mot de passe requis';
                                  if (value.length < 8) return 'Au moins 8 caractères';
                                  if (value == widget.temporaryPassword) {
                                    return 'Doit être différent du mot de passe temporaire';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirmer le mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Confirmation requise';
                                  if (value != _newPasswordController.text) {
                                    return 'Les mots de passe ne correspondent pas';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 28),
                              FilledButton(
                                onPressed: auth.isLoading ? null : _submit,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Valider et continuer'),
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
          ),
        ),
      ),
    );
  }
}