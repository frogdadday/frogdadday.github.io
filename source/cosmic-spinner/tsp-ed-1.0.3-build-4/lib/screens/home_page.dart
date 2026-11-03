// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/privacy_policy_button.dart';
import 'editor_page.dart';
import 'saved_page.dart';
import 'templates_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return CosmicScaffold(
      controller: controller,
      canGoBack: false,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            key: const Key('home-page'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: <Widget>[
              Text(
                'What shall the universe decide?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a path. The frog will handle the cosmic paperwork.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
              ),
              if (controller.draft != null) ...<Widget>[
                const SizedBox(height: 18),
                Card(
                  color: const Color(0xFF263056),
                  child: ListTile(
                    key: const Key('resume-draft'),
                    leading: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFFFFDC45),
                    ),
                    title: const Text('Resume unfinished spinner'),
                    subtitle: Text(
                      controller.draft!.title.trim().isEmpty
                          ? 'Your mysterious untitled wheel'
                          : controller.draft!.title,
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => _push(
                      context,
                      EditorPage(
                        controller: controller,
                        initial: controller.draft,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _HomeChoice(
                key: const Key('templates-option'),
                icon: Icons.auto_awesome_motion_rounded,
                title: 'Template Spinners',
                subtitle: 'Use one now or turn it into your own wheel.',
                color: const Color(0xFF7667F5),
                onTap: () =>
                    _push(context, TemplatesPage(controller: controller)),
              ),
              const SizedBox(height: 14),
              _HomeChoice(
                key: const Key('saved-option'),
                icon: Icons.bookmarks_rounded,
                title: 'Saved Spinners',
                subtitle: controller.saved.isEmpty
                    ? 'Your saved universe is waiting.'
                    : '${controller.saved.length} wheel${controller.saved.length == 1 ? '' : 's'} ready to spin.',
                color: const Color(0xFF37A7FF),
                onTap: () => _push(context, SavedPage(controller: controller)),
              ),
              const SizedBox(height: 14),
              _HomeChoice(
                key: const Key('create-option'),
                icon: Icons.add_circle_outline_rounded,
                title: 'Create Your Own',
                subtitle: 'Name it, color it, and add 2–20 possibilities.',
                color: AppColors.vibrantGreen,
                onTap: () => _push(context, EditorPage(controller: controller)),
              ),
              const SizedBox(height: 18),
              const Center(child: PrivacyPolicyButton()),
            ],
          );
        },
      ),
    );
  }
}

// ////Block Two//////////////////////////////////////////////////////////////
class _HomeChoice extends StatelessWidget {
  const _HomeChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 31),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.frogYellow,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
