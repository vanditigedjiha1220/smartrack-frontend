import 'package:local_auth/local_auth.dart';

// Enveloppe autour de local_auth — centralise la détection du capteur et
// l'invite biométrique, pour ne pas disperser cette logique dans les écrans.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // Vrai seulement si l'appareil a un capteur ET que l'utilisateur a
  // effectivement enregistré au moins une empreinte dans les réglages du
  // téléphone — sans ça, canCheckBiometrics peut être vrai alors qu'aucune
  // empreinte n'est réellement utilisable.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      // Sur certains appareils/émulateurs sans capteur, ces appels peuvent
      // lever une exception plutôt que renvoyer false — on traite ça comme
      // "non disponible" plutôt que de faire planter l'écran.
      return false;
    }
  }

  // Déclenche l'invite native (empreinte, ou visage selon l'appareil).
  // Renvoie true seulement si l'utilisateur a réussi l'authentification.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // refuse le repli sur code PIN/schéma — on veut vraiment l'empreinte
          stickyAuth: true, // survit si l'app passe brièvement en arrière-plan pendant l'invite
        ),
      );
    } catch (_) {
      return false;
    }
  }
}