// ////Block One//////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../services/app_controller.dart';
import '../services/content_guard.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';
import '../widgets/scheme_picker.dart';
import '../widgets/labeled_icon_button.dart';
import '../widgets/local_saving_dialog.dart';
import 'preview_page.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.controller,
    this.initial,
    this.fromTemplate = false,
  });

  final AppController controller;
  final SpinnerModel? initial;
  final bool fromTemplate;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  late final TextEditingController titleController;
  late final TextEditingController categoryController;
  late List<TextEditingController> sliceControllers;
  late Color selectedColor;
  late WheelScheme selectedScheme;
  late String spinnerId;
  Timer? draftTimer;
  bool busy = false;
  bool previewOpen = false;
  bool dirty = false;
  bool allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.initial;
    spinnerId =
        initial?.id ?? 'spinner-${DateTime.now().microsecondsSinceEpoch}';
    titleController = TextEditingController(text: initial?.title ?? '');
    categoryController = TextEditingController(text: initial?.category ?? '');
    final slices = initial?.slices ?? const <String>['', ''];
    sliceControllers = slices
        .map((text) => TextEditingController(text: text))
        .toList();
    selectedColor = initial?.color ?? spinnerPalette.first;
    selectedScheme = initial?.scheme ?? WheelScheme.cosmic;
    titleController.addListener(_changed);
    categoryController.addListener(_changed);
    for (final controller in sliceControllers) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    draftTimer?.cancel();
    titleController.removeListener(_changed);
    titleController.dispose();
    categoryController.removeListener(_changed);
    categoryController.dispose();
    for (final controller in sliceControllers) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  SpinnerModel get current => SpinnerModel(
    id: spinnerId,
    title: titleController.text,
    slices: sliceControllers.map((controller) => controller.text).toList(),
    colorValue: selectedColor.toARGB32(),
    scheme: selectedScheme,
    category: categoryController.text.trim(),
  );

  List<String> get _existingCategories {
    final categories = <String, String>{};
    for (final spinner in widget.controller.saved) {
      final category = spinner.category.trim();
      if (category.isNotEmpty) {
        categories.putIfAbsent(category.toLowerCase(), () => category);
      }
    }
    final values = categories.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  void _changed() {
    setState(() => dirty = true);
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) widget.controller.saveDraft(current);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && dirty && !previewOpen) {
      draftTimer?.cancel();
      unawaited(widget.controller.saveDraft(current));
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  ////Block Two////////////////////////////////////////////////////////////
  Future<void> _setSliceCount(int next) async {
    next = next.clamp(2, 20);
    if (next == sliceControllers.length) return;
    if (next < sliceControllers.length) {
      final removeCount = sliceControllers.length - next;
      final removesContent = sliceControllers
          .skip(next)
          .any((controller) => controller.text.trim().isNotEmpty);
      final confirmed = removesContent
          ? await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Shrink this universe?'),
                content: Text(
                  'This removes the last $removeCount slice${removeCount == 1 ? '' : 's'}. The frog cannot un-lick that envelope.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep them'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove slices'),
                  ),
                ],
              ),
            )
          : true;
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      if (next > sliceControllers.length) {
        while (sliceControllers.length < next) {
          final controller = TextEditingController()..addListener(_changed);
          sliceControllers.add(controller);
        }
      } else {
        final removed = sliceControllers.sublist(next);
        sliceControllers = sliceControllers.sublist(0, next);
        for (final controller in removed) {
          controller.removeListener(_changed);
          controller.dispose();
        }
      }
      _changed();
    });
  }

  Future<void> _commit() async {
    FocusScope.of(context).unfocus();
    final model = current;
    final duplicateTitle = widget.controller.saved.any(
      (saved) =>
          saved.id != model.id &&
          saved.title.trim().toLowerCase() == model.title.trim().toLowerCase(),
    );
    final warning = _friendlyWarning(model, duplicateTitle);
    if (warning != null || duplicateTitle) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.sentiment_very_satisfied_rounded,
            color: AppColors.frogYellow,
            size: 40,
          ),
          title: const Text('The frog has questions'),
          content: Text(
            warning ?? 'A spinner already answers to this title. That is allowed, but the frog may need tiny name tags.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send it to the cosmos anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    draftTimer?.cancel();
    if (!await widget.controller.saveDraft(model)) return;
    previewOpen = true;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PreviewPage(controller: widget.controller, spinner: model),
      ),
    );
    previewOpen = false;
  }

  String? _friendlyWarning(SpinnerModel model, bool duplicateTitle) {
    if (duplicateTitle) {
      return 'A spinner already uses this title. That is allowed, but the frog may need tiny name tags.';
    }
    if (model.title.trim().isEmpty) {
      return 'This spinner has no title yet. Give it one, or continue with an untitled wheel.';
    }
    if (model.slices.any((slice) => slice.trim().isEmpty)) {
      return 'One or more choices are blank. Fill them in, or continue with blank slices.';
    }
    final choices = model.slices
        .map((slice) => slice.trim().toLowerCase())
        .toList();
    if (choices.toSet().length != choices.length) {
      return 'Some choices are repeated. That is allowed if you want extra chances for them.';
    }
    if (ContentGuard.needsFriendlyWarning(model.title, model.slices)) {
      return 'Some text is unusually symbolic. Check it looks the way you intend, then continue if it does.';
    }
    return null;
  }

  Future<void> _handleBack() async {
    if (!dirty) {
      setState(() => allowPop = true);
      Navigator.pop(context);
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this spinner?'),
        content: const Text(
          'The frog can hold onto your unfinished cosmic paperwork.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Continue editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'draft'),
            child: const Text('Save draft & leave'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result == 'continue') return;
    if (result == 'draft' &&
        !await requestLocalSaving(context, widget.controller)) {
      return;
    }
    if (!mounted) return;
    draftTimer?.cancel();
    dirty = false;
    final saved = result == 'draft'
        ? await widget.controller.saveDraft(current)
        : await widget.controller.clearDraft();
    if (!saved) {
      dirty = true;
      return;
    }
    dirty = false;
    if (!mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  ////Block Three//////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _guard(_handleBack);
      },
      child: CosmicScaffold(
        controller: widget.controller,
        body: ListView(
          key: const Key('spinner-editor'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Text(
              widget.fromTemplate
                  ? 'Make this template yours'
                  : 'Build your spinner',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('spinner-title-field'),
              enabled: !busy,
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Spinner title',
                hintText: 'Places to Eat',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Where should this spinner live?',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Categories keep related spinners together in Saved Spinners.',
            ),
            const SizedBox(height: 12),
            if (_existingCategories.isEmpty)
              const _NewToCategoriesCard()
            else ...<Widget>[
              Text(
                'Choose an existing category',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _existingCategories)
                    ChoiceChip(
                      key: Key('category-choice-${category.toLowerCase()}'),
                      label: Text(category),
                      selected:
                          categoryController.text.trim().toLowerCase() ==
                          category.toLowerCase(),
                      onSelected: busy
                          ? null
                          : (_) {
                              FocusScope.of(context).unfocus();
                              categoryController.text = category;
                            },
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              key: const Key('spinner-category-field'),
              enabled: !busy,
              controller: categoryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Or make a new category',
                hintText: 'Movies, Music, Family...',
                helperText:
                    'Leave blank to save this spinner in Uncategorized.',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Number of slices',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: LabeledIconButton(
                    label: 'Remove',
                    tooltip: 'Remove one slice',
                    onPressed: !busy && sliceControllers.length > 2
                        ? () => _guard(
                            () => _setSliceCount(sliceControllers.length - 1),
                          )
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${sliceControllers.length}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Flexible(
                  child: LabeledIconButton(
                    label: 'Add',
                    tooltip: 'Add one slice',
                    onPressed: !busy && sliceControllers.length < 20
                        ? () => _guard(
                            () => _setSliceCount(sliceControllers.length + 1),
                          )
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 20),
            Text(
              'Numbered slices',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < sliceControllers.length; i++) ...<Widget>[
              TextField(
                key: Key('slice-field-$i'),
                enabled: !busy,
                controller: sliceControllers[i],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Slice ${i + 1}',
                  prefixIcon: CircleAvatar(
                    radius: 14,
                    backgroundColor: current.sliceColor(i),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: current.sliceTextColor(i),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            SchemePicker(
              spinner: current,
              enabled: !busy,
              onSchemeChanged: (scheme) {
                setState(() => selectedScheme = scheme);
                _changed();
              },
              onColorChanged: (color) {
                setState(() => selectedColor = color);
                _changed();
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('commit-spinner'),
              onPressed: busy ? null : () => _guard(_commit),
              icon: const Icon(Icons.public_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Commit to the Cosmos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewToCategoriesCard extends StatelessWidget {
  const _NewToCategoriesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.elevated,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.folder_copy_rounded, color: AppColors.frogYellow),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'New to categories? Make one called “Movies,” then save your Horror and Comedy spinners inside it.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
