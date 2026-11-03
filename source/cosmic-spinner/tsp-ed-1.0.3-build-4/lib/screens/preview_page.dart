// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../services/app_controller.dart';
import '../services/content_guard.dart';
import '../widgets/gentle_note_dialog.dart';
import '../widgets/local_saving_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/spinner_wheel.dart';
import '../widgets/choices_sheet.dart';
import 'home_page.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({
    super.key,
    required this.controller,
    required this.spinner,
  });

  final AppController controller;
  final SpinnerModel spinner;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool busy = false;
  AppController get controller => widget.controller;
  SpinnerModel get spinner => widget.spinner;
  Future<void> _save(BuildContext context) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!await requestLocalSaving(context, controller)) return;
      if (!await controller.saveSpinner(spinner)) return;
      if (!context.mounted) return;
      final showSupportNote =
          ContentGuard.supportKeywordIn([spinner.title, ...spinner.slices]) !=
          null;
      await showDialog<void>(
        context: context,
        barrierDismissible: showSupportNote,
        builder: (context) => showSupportNote
            ? const GentleNoteDialog()
            : AlertDialog(
                icon: const Icon(
                  Icons.bookmark_added_rounded,
                  color: AppColors.vibrantGreen,
                  size: 42,
                ),
                title: const Text('Your wheel is among the stars!'),
                content: const Text(
                  'You can now find it anytime under Saved Spinners.',
                ),
                actions: <Widget>[
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back home'),
                  ),
                ],
              ),
      );
      if (!context.mounted) return;
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => HomePage(controller: controller),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: CosmicScaffold(
        controller: controller,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wheelSize = constraints.biggest.shortestSide.clamp(
              220.0,
              430.0,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: <Widget>[
                  Text(
                    spinner.title.trim().isEmpty
                        ? '(Untitled Spinner)'
                        : spinner.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'One last look before it becomes official.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox.square(
                      dimension: wheelSize,
                      child: SpinnerWheel(spinner: spinner),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showChoicesSheet(context, spinner),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('View all choices'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('One Last Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('save-whole-spinner'),
                          onPressed: busy ? null : () => _save(context),
                          icon: const Icon(Icons.bookmark_add_rounded),
                          label: const Text('Save Whole Spinner'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
