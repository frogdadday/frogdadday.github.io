import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://frogdadday.github.io/-Cosmic-Converter-Privacy-Policy/',
  );

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The privacy policy could not be opened. Please try again.',
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _privacyPolicyUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showLaunchError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showLaunchError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Cosmic Converter privacy policy',
      child: Tooltip(
        message: 'Privacy Policy',
        child: IconButton(
          onPressed: () => _openPrivacyPolicy(context),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          icon: const Icon(
            Icons.privacy_tip_outlined,
            color: Colors.tealAccent,
          ),
        ),
      ),
    );
  }
}
