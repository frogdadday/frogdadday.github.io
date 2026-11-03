import 'package:flutter/material.dart';

import '../services/app_controller.dart';

Future<bool> requestLocalSaving(
  BuildContext context,
  AppController controller,
) async {
  await controller.ready;
  if (!context.mounted || !controller.loaded) return false;
  if (controller.localSavingAllowed) return true;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Save Your Spinners?'),
      content: const Text(
        'Cosmic Spinner can save spinners you create or edit, including unfinished drafts, so you can use them again later.\n\n'
        'They are saved in the app’s private storage on your device. This does not give the app access to your photos or other files. Cosmic Spinner does not upload or share your spinner content. Your Android backup settings may include app data in backups.\n\n'
        'Allow Cosmic Spinner to save and recall your spinners?\n\n'
        'Allow is remembered for future saves. Not Now leaves your current work in this session only; we’ll ask again next time you try to save.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (allow != true || !context.mounted) return false;
  return controller.allowLocalSaving();
}
