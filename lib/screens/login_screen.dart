import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_provider.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'server_settings_screen.dart';
import 'force_password_change_screen.dart';
import 'admin/admin_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'supervisor/supervisor_home_screen.dart';

// Point d'entrée UNIQUE pour les 3 rôles (admin desktop, enseignant mobile,
// superviseur mobile) — c'est le rôle renvoyé par le serveur dans /auth/login
// qui détermine l'écran d'accueil affiché ensuite, pas un choix fait dans l'app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricService = BiometricService();
  bool _obscurePassword = true;

  // Vrai seulement si (a) l'appareil a un capteur utilisable ET (b) une
  // connexion par empreinte a déjà été activée précédemment sur cet appareil —
  // les deux conditions sont vérifiées de façon asynchrone au chargement.
  bool _biometricLoginAvailable = false;
  bool _checkingBiometric = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final auth = context.read<AuthProvider>();
    final deviceSupports = await _biometricService.isAvailable();
    final alreadyEnabled = await auth.isBiometricLoginEnabled();
    if (!mounted) return;
    setState(() {
      _biometricLoginAvailable = deviceSupports && alreadyEnabled;
      _checkingBiometric = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final password = _passwordController.text;
    final success = await auth.login(_emailController.text.trim(), password);

    if (!mounted) return;

    if (success) {
      if (auth.mustChangePassword) {
        // Mot de passe temporaire donné par l'admin : on force le changement
        // avant d'aller où que ce soit. Le serveur refuserait de toute façon
        // tout autre appel (voir JwtAuthGuard côté backend).
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ForcePasswordChangeScreen(temporaryPassword: password),
          ),
        );
        return;
      }

      // Login normal réussi (pas de changement de mot de passe forcé) — c'est
      // le bon moment pour proposer d'activer la connexion par empreinte,
      // seulement si l'appareil le permet et que ce n'est pas déjà activé.
      final deviceSupports = await _biometricService.isAvailable();
      final alreadyEnabled = await auth.isBiometricLoginEnabled();
      if (deviceSupports && !alreadyEnabled) {
        await _offerEnableBiometric();
      }

      if (!mounted) return;
      _navigateByRole(auth.currentUser!.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'Erreur de connexion'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // Boîte de dialogue proposant d'activer la connexion par empreinte, affichée
  // uniquement juste après un login par mot de passe réussi.
  Future<void> _offerEnableBiometric() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.skyLight, shape: BoxShape.circle),
              child: const Icon(Icons.fingerprint_rounded, size: 30, color: AppColors.skyDeep),
            ),
            const SizedBox(height: 14),
            const Text('Connexion par empreinte', textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          'Voulez-vous activer la connexion par empreinte digitale ? '
          'Vous pourrez ensuite vous connecter sans ressaisir votre mot de passe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13.5, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activer')),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    // On exige une confirmation biométrique réelle AVANT d'activer — l'utilisateur
    // doit prouver qu'il possède bien cette empreinte, pas juste cliquer "Oui".
    final confirmed = await _biometricService.authenticate(
      reason: "Confirmez votre empreinte pour activer la connexion rapide",
    );

    if (!confirmed || !mounted) return;

    await context.read<AuthProvider>().enableBiometricLogin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Connexion par empreinte activée'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Déclenchée par le bouton empreinte de l'écran de login — invite native
  // d'abord, puis échange du refresh token contre une session, SANS mot de passe.
  Future<void> _loginWithBiometrics() async {
    final confirmed = await _biometricService.authenticate(
      reason: 'Connectez-vous avec votre empreinte',
    );
    if (!confirmed || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithBiometrics();
    if (!mounted) return;

    if (success) {
      if (auth.mustChangePassword) {
        // Cas rare mais possible : l'admin a réinitialisé le mot de passe
        // pendant que le refresh token était stocké — même redirection forcée.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ForcePasswordChangeScreen(temporaryPassword: ''),
          ),
        );
      } else {
        _navigateByRole(auth.currentUser!.role);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'Connexion par empreinte impossible'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // On rafraîchit la disponibilité — si le refresh token a expiré,
      // loginWithRefreshToken() l'a déjà désactivé côté ApiService.
      _checkBiometricAvailability();
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

    return SkyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: Colors.white.withOpacity(0.5),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(Icons.settings_ethernet_rounded, color: AppColors.ink.withOpacity(0.6), size: 20),
                      tooltip: 'Adresse du serveur',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        const _Logo(),
                        const SizedBox(height: 36),
                        GlassCard(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Connexion',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: AppColors.ink),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Email requis';
                                    if (!value.contains('@')) return 'Email invalide';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Mot de passe requis';
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Se connecter'),
                                ),
                                if (!_checkingBiometric && _biometricLoginAvailable) ...[
                                  const SizedBox(height: 22),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: AppColors.inkMuted.withOpacity(0.25))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('ou',
                                            style: TextStyle(color: AppColors.inkMuted.withOpacity(0.7), fontSize: 12)),
                                      ),
                                      Expanded(child: Divider(color: AppColors.inkMuted.withOpacity(0.25))),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: _BiometricButton(
                                      enabled: !auth.isLoading,
                                      onTap: _loginWithBiometrics,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: AppColors.inkMuted.withOpacity(0.7)),
                            const SizedBox(width: 6),
                            Text(
                              'Accès sécurisé — admin, enseignant, superviseur',
                              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouton rond avec icône d'empreinte, dans le style du thème — plus visible
// et plus évocateur qu'un simple bouton texte pour cette action spécifique.
class _BiometricButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _BiometricButton({required this.enabled, required this.onTap});

  @override
  State<_BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<_BiometricButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: widget.enabled ? (_) => _controller.forward() : null,
          onTapUp: widget.enabled ? (_) => _controller.reverse() : null,
          onTapCancel: widget.enabled ? () => _controller.reverse() : null,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: 1 - _controller.value,
              child: child,
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.enabled
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.skyDeep, AppColors.skyMid],
                      )
                    : null,
                color: widget.enabled ? null : AppColors.inkMuted.withOpacity(0.2),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: AppColors.skyDeep.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Connexion par empreinte',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: widget.enabled ? AppColors.ink : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

// Monogramme "S" dans un dégradé, plutôt qu'une icône Material générique —
// identité visuelle propre à Smartrack.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.skyDeep, AppColors.skyMid],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.skyDeep.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Smartrack',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: 0.2),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestion de notes & bulletins',
          style: TextStyle(fontSize: 14, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}