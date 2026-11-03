// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../models/chore_list.dart';
import '../models/daily_plan.dart';
import '../services/chore_store.dart';
import '../services/cosmic_copy.dart';
import '../services/local_calendar.dart';
import '../services/native_bridge.dart';
import '../widgets/responsive_list_view.dart';
import 'create_chore_list_page.dart';

class SavedListsPage extends StatelessWidget {
  const SavedListsPage({super.key, required this.store});

  final ChoreStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (store.loadError != null) {
          return ResponsiveListView(
            children: [
              Text(store.loadError!),
              FilledButton(
                onPressed: store.load,
                child: const Text('Retry loading saved lists'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final restore = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Restore the last saved copy?'),
                      content: const Text(
                        'This replaces the unreadable current copy with the previous saved version on this device.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Restore copy'),
                        ),
                      ],
                    ),
                  );
                  if (restore != true || !context.mounted) return;
                  try {
                    await store.restoreBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('The last saved copy was restored.'),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'The backup could not be restored. Your current data was left unchanged.',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore last saved copy'),
              ),
            ],
          );
        }
        if (store.lists.isEmpty) {
          return const _EmptySavedLists();
        }
        return ResponsiveListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            Text(
              context.cosmicCopy('Saved chore lists'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Every list repeats automatically. Open one to review today’s rotation or prepare its message.',
            ),
            const SizedBox(height: 14),
            for (final list in store.lists)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    child: Icon(Icons.checklist_rounded),
                  ),
                  title: Text(
                    context.cosmicCopy(list.title),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    context.cosmicCopy(
                      list.isSpecialProject && list.addToListId == null
                          ? 'Special project • choose a weekly or work-week plan'
                          : list.addToListId == null
                          ? '${list.template.label} • repeats automatically • ${list.people.length} ${list.people.length == 1 ? 'person' : 'people'} • ${list.rotationMode.label}'
                          : '${list.template.label} project list • adds chores into another daily plan',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          SavedListDetailPage(list: list, store: store),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptySavedLists extends StatelessWidget {
  const _EmptySavedLists();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_note_rounded,
              size: 68,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved lists yet',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.cosmicCopy(
                'Create a list, add your people, and give the frog some chores to organize.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// /////Block Two/////////////////////////////////////////////////////////////
class SavedListDetailPage extends StatefulWidget {
  const SavedListDetailPage({
    super.key,
    required this.list,
    required this.store,
    this.initialDate,
  });

  final ChoreList list;
  final ChoreStore store;
  final DateTime? initialDate;

  @override
  State<SavedListDetailPage> createState() => _SavedListDetailPageState();
}

class _SavedListDetailPageState extends State<SavedListDetailPage>
    with LocalDateObserver {
  DateTime? _previewDate;
  DateTime get selectedDate => _previewDate ?? localNow;
  int? get selectedDay => list.dayIndexForDate(selectedDate);
  bool _deleting = false;
  late ChoreList list;

  @override
  void initState() {
    super.initState();
    list = widget.list;
    _previewDate = widget.initialDate;
  }

  Future<void> _prepareMessage(DailyPlan plan) async {
    refreshLocalDate();
    final recipients = plan.mainList.messageRecipients;
    try {
      final opened = await NativeBridge.shareMessage(
        body: plan.messageForMode(cosmicMode: context.isCosmicMode),
        recipients: recipients,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No messaging or sharing app was available.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The message could not be opened. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final linkedProjects = widget.store.linkedProjectsFor(list.id);
    String? moveProjectsTo;
    var deleteProjects = false;
    if (linkedProjects.isNotEmpty) {
      final candidates = widget.store.mainPlans
          .where((candidate) => candidate.id != list.id)
          .toList();
      final choice = await showDialog<_ProjectDeleteChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This plan has special projects'),
          content: Text(
            '${linkedProjects.length} Special & Deep Cleaning ${linkedProjects.length == 1 ? 'list depends' : 'lists depend'} on this plan. Choose where those projects should go before deleting it.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep plan'),
            ),
            if (candidates.isNotEmpty)
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, _ProjectDeleteChoice.move),
                child: const Text('Move projects'),
              ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _ProjectDeleteChoice.delete),
              child: const Text('Delete plan and projects'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == _ProjectDeleteChoice.move) {
        moveProjectsTo = await _chooseProjectDestination(candidates);
        if (!mounted || moveProjectsTo == null) return;
      } else {
        deleteProjects = true;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.cosmicCopy('Delete this chore list?')),
        content: const Text('This removes the saved list from this device.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.store.remove(
        list.id,
        moveProjectsTo: moveProjectsTo,
        deleteProjects: deleteProjects,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The list could not be deleted. It is still saved. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _chooseProjectDestination(List<ChoreList> candidates) {
    String? selected = candidates.first.id;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move special projects to'),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          items: candidates
              .map(
                (candidate) => DropdownMenuItem<String>(
                  value: candidate.id,
                  child: Text(candidate.title),
                ),
              )
              .toList(),
          onChanged: (value) => selected = value,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Move projects'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (editorContext) => Scaffold(
          appBar: AppBar(
            title: Text(editorContext.cosmicCopy('Edit chore list')),
          ),
          body: CreateChoreListPage(
            store: widget.store,
            initialList: list,
            onSaved: () => Navigator.pop(editorContext, true),
          ),
        ),
      ),
    );
    if (changed != true || !mounted) return;
    setState(() {
      list = widget.store.lists.firstWhere((item) => item.id == list.id);
      _previewDate = null;
    });
  }

  // /////Block Two A////////////////////////////////////////////////////////
  Future<void> _duplicate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (editorContext) => Scaffold(
          appBar: AppBar(
            title: Text(editorContext.cosmicCopy('Duplicate chore list')),
          ),
          body: CreateChoreListPage(
            store: widget.store,
            initialList: list,
            isCopy: true,
            onSaved: () => Navigator.pop(editorContext, true),
          ),
        ),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A separate copy of the list was saved.')),
      );
    }
  }

  // /////Block Three/////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final linkedMain = list.addToListId == null
        ? null
        : widget.store.lists
              .where((item) => item.id == list.addToListId)
              .firstOrNull;
    if (list.isSpecialProject && linkedMain?.isMainPlan == true) {
      return _linkedProjectPage(context, linkedMain!);
    }
    if (list.isSpecialProject) return _orphanedProjectPage(context);
    final plan = DailyPlan.forList(
      mainList: list,
      allLists: widget.store.lists,
      date: selectedDate,
    );
    final day = list.dayIndexForDate(selectedDate);
    final assignments = plan.assignments;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.cosmicCopy(list.title)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit everything',
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Duplicate list',
            onPressed: _duplicate,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Delete list',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Preview a day',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    MaterialLocalizations.of(context)
                        .formatFullDate(selectedDate),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Choose date'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2200),
                          );
                          if (picked != null && mounted) {
                            setState(() => _previewDate = picked);
                          }
                        },
                      ),
                      TextButton(
                        onPressed: () => setState(() => _previewDate = null),
                        child: const Text('Today'),
                      ),
                    ],
                  ),
                  if (day == null)
                    Text(
                      context.cosmicCopy('No chores scheduled on weekends.'),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    list.remindersEnabled
                        ? 'Daily reminder: ${list.formattedTime}'
                        : 'Daily reminder: Off',
                  ),
                  const SizedBox(height: 4),
                  Text('Rotation: ${list.rotationMode.label}'),
                ],
              ),
            ),
          ),
          if (plan.extraListTitles.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_task_rounded),
                title: Text(
                  'Also scheduled: ${plan.extraListTitles.join(', ')}',
                ),
                subtitle: Text(
                  context.cosmicCopy(
                    'Those projects go to the first person in today’s rotation.',
                  ),
                ),
              ),
            ),
          for (final assignment in assignments)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    assignment.person.name.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(
                  assignment.person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  assignment.chores.isEmpty
                      ? context.cosmicCopy('No chores today')
                      : assignment.chores
                            .map((chore) => chore.title)
                            .join(' • '),
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: day == null ? null : () => _prepareMessage(plan),
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Prepare message'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your messaging app opens with the assignments filled in. You choose the conversation and tap Send.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // /////Block Four//////////////////////////////////////////////////////////
  Widget _linkedProjectPage(BuildContext context, ChoreList mainList) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.cosmicCopy(list.title)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit project list',
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Duplicate list',
            onPressed: _duplicate,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Delete list',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveListView(
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.account_tree_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'This is a project add-on',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.cosmicCopy(
                      'Its scheduled chores automatically appear in ${mainList.title}. On those days, they go to the first person in ${mainList.title}’s rotation.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => SavedListDetailPage(
                          list: mainList,
                          store: widget.store,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.today_rounded),
                    label: Text(context.cosmicCopy('Open ${mainList.title}')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.cosmicCopy(
                      'Use the pencil above to change this project list’s dates or chores.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orphanedProjectPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.cosmicCopy(list.title)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit project list',
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Duplicate list',
            onPressed: _duplicate,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Delete list',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveListView(
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.link_off_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a main plan',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This special project is safely paused because its weekly plan is no longer available. Edit it to attach it to a saved Full week or Work week plan.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Choose a main plan'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// /////Block Five///////////////////////////////////////////////////////////
enum _ProjectDeleteChoice { move, delete }
