import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _urlController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _urlController.addListener(() {
      if (_saved) setState(() => _saved = false);
    });
  }

  Future<void> _save() async {
    await ApiConfig.setBaseUrl(_urlController.text);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adresse du serveur enregistrée'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SkyScaffold(
      appBar: AppBar(title: const Text('Adresse du serveur')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.skyLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.wifi_rounded, color: AppColors.skyDeep, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Réseau local', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.skyLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: AppColors.skyDeep),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Adresse du serveur de l'établissement (visible sur l'ordinateur admin, "
                        'ex: http://192.168.1.42:3000). Demandez-la à votre administrateur si '
                        'vous ne la connaissez pas.',
                        style: TextStyle(color: AppColors.inkMuted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL du serveur',
                  hintText: 'http://192.168.1.42:3000',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: Icon(_saved ? Icons.check_rounded : Icons.save_outlined, size: 18),
                label: Text(_saved ? 'Enregistré' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}