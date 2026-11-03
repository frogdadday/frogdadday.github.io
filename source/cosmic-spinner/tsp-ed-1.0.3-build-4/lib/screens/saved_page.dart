import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/spinner_wheel.dart';
import 'editor_page.dart';
import 'spinner_page.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => CosmicScaffold(
    controller: controller,
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final groups = _categoryGroups(controller.saved);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: <Widget>[
            Text(
              'Saved Spinners',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Choose a category to find a wheel.'),
            const SizedBox(height: 16),
            if (controller.saved.isEmpty)
              const _EmptySaved()
            else ...<Widget>[
              _CategoryCard(
                icon: Icons.auto_awesome_rounded,
                title: 'All saved spinners',
                count: controller.saved.length,
                onTap: () => _openCategory(context, null, 'All saved spinners'),
              ),
              for (final group in groups)
                _CategoryCard(
                  icon: group.category.isEmpty
                      ? Icons.folder_off_rounded
                      : Icons.folder_rounded,
                  title: group.category.isEmpty
                      ? 'Uncategorized'
                      : group.category,
                  count: group.spinners.length,
                  onTap: () => _openCategory(
                    context,
                    group.category,
                    group.category.isEmpty ? 'Uncategorized' : group.category,
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );

  void _openCategory(BuildContext context, String? category, String title) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CategorySpinnersPage(
          controller: controller,
          category: category,
          title: title,
        ),
      ),
    );
  }
}

class CategorySpinnersPage extends StatefulWidget {
  const CategorySpinnersPage({
    super.key,
    required this.controller,
    required this.category,
    required this.title,
  });
  final AppController controller;
  final String? category;
  final String title;
  @override
  State<CategorySpinnersPage> createState() => _CategorySpinnersPageState();
}

class _CategorySpinnersPageState extends State<CategorySpinnersPage> {
  bool opening = false;

  Future<void> _open(SpinnerModel spinner, {bool edit = false}) async {
    if (opening) return;
    opening = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => edit
              ? EditorPage(controller: widget.controller, initial: spinner)
              : SpinnerPage(controller: widget.controller, spinner: spinner),
        ),
      );
    } finally {
      opening = false;
    }
  }

  Future<void> _delete(SpinnerModel spinner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this wheel into the void?'),
        content: Text(
          'The frog will release “${spinner.title}” from this universe.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep It'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.darkRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Spinner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await widget.controller.deleteSpinner(spinner.id);
    if (!mounted) return;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    deletionNotice;
    deletionNotice = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // A SnackBar with an action can remain visible indefinitely when an
        // accessibility service is active. Give this reversible action a
        // clear, reliable end point in every case.
        duration: const Duration(seconds: 8),
        content: Text(
          saved
              ? '“${spinner.title}” drifted into the void.'
              : '“${spinner.title}” was removed for this session, but saving failed. Retry saving before closing the app.',
        ),
        action: saved
            ? SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  deletionNotice.close();
                  final restored = await widget.controller.restoreSpinner(
                    spinner,
                  );
                  if (!restored && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The spinner returned for this session, but could not be saved. Retry saving before closing the app.',
                        ),
                      ),
                    );
                  }
                },
              )
            : null,
      ),
    );
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) deletionNotice.close();
    });
  }

  @override
  Widget build(BuildContext context) => CosmicScaffold(
    controller: widget.controller,
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final spinners = widget.controller.saved.where((spinner) {
          final category = spinner.category.trim();
          if (widget.category == null) return true;
          if (widget.category!.isEmpty) return category.isEmpty;
          return category.toLowerCase() == widget.category!.toLowerCase();
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: <Widget>[
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${spinners.length} saved spinner${spinners.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 14),
            if (spinners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No wheels in this category yet.')),
              )
            else
              for (final spinner in spinners)
                _SpinnerCard(
                  spinner: spinner,
                  onOpen: () => _open(spinner),
                  onEdit: () => _open(spinner, edit: true),
                  onDelete: () => _delete(spinner),
                ),
          ],
        );
      },
    ),
  );
}

class _CategoryGroup {
  const _CategoryGroup(this.category, this.spinners);
  final String category;
  final List<SpinnerModel> spinners;
}

List<_CategoryGroup> _categoryGroups(List<SpinnerModel> spinners) {
  final grouped = <String, List<SpinnerModel>>{};
  final labels = <String, String>{};
  for (final spinner in spinners) {
    final category = spinner.category.trim();
    final key = category.toLowerCase();
    grouped.putIfAbsent(key, () => <SpinnerModel>[]).add(spinner);
    labels.putIfAbsent(key, () => category);
  }
  final groups = grouped.entries
      .map((entry) => _CategoryGroup(labels[entry.key]!, entry.value))
      .toList();
  groups.sort((a, b) {
    if (a.category.isEmpty) return 1;
    if (b.category.isEmpty) return -1;
    return a.category.toLowerCase().compareTo(b.category.toLowerCase());
  });
  return groups;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.frogYellow),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$count spinner${count == 1 ? '' : 's'}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _SpinnerCard extends StatelessWidget {
  const _SpinnerCard({
    required this.spinner,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final SpinnerModel spinner;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onOpen,
      leading: SizedBox.square(
        dimension: 48,
        child: SpinnerWheel(spinner: spinner, showLabels: false),
      ),
      title: Text(
        spinner.title.trim().isEmpty ? '(Untitled Spinner)' : spinner.title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.frogYellow,
          fontSize: 18,
        ),
      ),
      subtitle: Text('${spinner.slices.length} slices'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Spinner options',
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.more_vert, color: AppColors.frogYellow),
              Text('Options', style: TextStyle(color: AppColors.frogYellow)),
            ],
          ),
        ),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
          PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Icon(Icons.explore_off_rounded, size: 48, color: Color(0xFFFFDC45)),
          SizedBox(height: 12),
          Text(
            'No saved spinners yet.',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Categories are created while building or editing a spinner.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
