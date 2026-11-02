import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({super.key});

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await const MethodChannel('frog_file_viewer/link')
          .invokeMethod<bool>('openPrivacyPolicy')
          .timeout(const Duration(seconds: 2));
      if (opened == true) return;
    } catch (_) {
      // Missing browsers and platform handlers are reported without
      // interrupting the user's current document work.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The privacy policy could not be opened. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open the Frog File Viewer privacy policy in your browser',
      child: Tooltip(
        message: 'Open privacy policy in your browser',
        child: OutlinedButton.icon(
          key: const Key('privacy-policy-button'),
          onPressed: () => _open(context),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('Privacy policy'),
        ),
      ),
    );
  }
}
