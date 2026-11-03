// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../services/native_bridge.dart';

class FrogHeartButton extends StatelessWidget {
  const FrogHeartButton({super.key});

  Future<void> _open(BuildContext context) async {
    final opened = await NativeBridge.openSupport();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The coffee link could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Optional support: Buy Me a Coffee',
      child: TextButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.favorite_rounded),
        label: const Text('Send Me a Coffee'),
      ),
    );
  }
}
