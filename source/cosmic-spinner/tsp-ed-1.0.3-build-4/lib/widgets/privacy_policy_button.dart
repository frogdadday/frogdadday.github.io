import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'labeled_icon_button.dart';

class PrivacyPolicyButton extends StatelessWidget {
  const PrivacyPolicyButton({super.key});

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await const MethodChannel('cosmic_spinner/link')
          .invokeMethod<bool>('openPrivacyPolicy')
          .timeout(const Duration(seconds: 2));
      if (opened == true) return;
    } catch (_) {
      // A missing browser or platform handler should not interrupt the app.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the privacy policy. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LabeledIconButton(
    key: const Key('privacy-policy-button'),
    label: 'Privacy Policy',
    tooltip: 'Open privacy policy in your browser',
    icon: const Icon(Icons.privacy_tip_outlined, size: 26),
    onPressed: () => _open(context),
  );
}
