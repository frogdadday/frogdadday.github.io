import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Offered after a successful explicit save, never during normal wheel use.
class GentleNoteDialog extends StatelessWidget {
  const GentleNoteDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: const Icon(
      Icons.favorite_outline_rounded,
      color: AppColors.frogYellow,
    ),
    title: const Text('A gentle note'),
    content: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'This app can’t know your intent. A few keywords prompted this message, but they may simply be part of a movie title, a joke, or something else entirely.',
        ),
        SizedBox(height: 16),
        Text(
          'If this is a hard moment in your life, you don’t have to face it alone. There are people who want to listen and help.',
        ),
        SizedBox(height: 16),
        Text(
          'In the U.S., call or text 988 to reach the Suicide & Crisis Lifeline, available 24/7. You don’t have to know what to say to reach out.',
        ),
        SizedBox(height: 16),
        Text(
          'If this message reached you in error, please forgive this small intrusion. Your spinner is saved and ready to use.',
        ),
        SizedBox(height: 16),
        Text(
          'Live and let love. Love and let live.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    ),
    actions: [
      TextButton(
        key: const Key('dismiss-gentle-note'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Dismiss'),
      ),
    ],
  );
}
