import 'package:flutter/material.dart';

class LabeledIconButton extends StatelessWidget {
  const LabeledIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
