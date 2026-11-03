// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/spinner_wheel.dart';
import 'editor_page.dart';
import 'spinner_page.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key, required this.controller});

  final AppController controller;

  Future<void> _choose(BuildContext context, SpinnerModel template) async {
    final edit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A wheel has appeared!'),
        content: Text(
          'Would you like to tune “${template.title}” before the frog deploys it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Just open it already'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Edit this first'),
          ),
        ],
      ),
    );
    if (edit == null || !context.mounted) return;
    if (edit) {
      final copy = template.copyWith(
        id: 'spinner-${DateTime.now().microsecondsSinceEpoch}',
        isTemplate: false,
      );
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EditorPage(
            controller: controller,
            initial: copy,
            fromTemplate: true,
          ),
        ),
      );
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              SpinnerPage(controller: controller, spinner: template),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CosmicScaffold(
      controller: controller,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: <Widget>[
          Text(
            'Ready-made constellations',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Templates stay unchanged. Edit one and its new version becomes yours.',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 16),
          for (final template in spinnerTemplates) ...<Widget>[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                leading: SizedBox.square(
                  dimension: 48,
                  child: SpinnerWheel(spinner: template, showLabels: false),
                ),
                title: Text(
                  template.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.frogYellow,
                  ),
                ),
                subtitle: Text(
                  '${template.slices.length} possibilities: ${template.slices.take(3).join(', ')}${template.slices.length > 3 ? '…' : ''}',
                ),
                trailing: const Icon(Icons.rocket_launch_rounded),
                onTap: () => _choose(context, template),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
