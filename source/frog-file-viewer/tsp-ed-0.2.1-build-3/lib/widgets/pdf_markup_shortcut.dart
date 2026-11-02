import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

enum _MarkupChoice { pen, highlighter, eraser, textBox, select, fingerDrawing }

/// Visible entry to the editor's existing annotation tools. No second
/// drawing layer or custom PDF serialization is introduced.
class PdfMarkupShortcut extends StatefulWidget {
  const PdfMarkupShortcut({
    super.key,
    required this.onChooseTool,
    required this.fingerDrawsInk,
    required this.onFingerDrawChanged,
  });

  final ValueChanged<PdfEditTool> onChooseTool;
  final bool fingerDrawsInk;
  final ValueChanged<bool> onFingerDrawChanged;

  @override
  State<PdfMarkupShortcut> createState() => _PdfMarkupShortcutState();
}

/// Keeps the host's Markup shortcut reachable in both editor layouts.
///
/// `PdfEditingToolbar.leading` is rendered by the desktop toolbar, but the
/// package's compact phone toolbar intentionally omits host leading widgets.
/// On phones this wrapper gives the shortcut a small row of its own above the
/// otherwise-stock toolbar; wider layouts continue to use the normal leading
/// slot.
class PdfMarkupToolbar extends StatelessWidget {
  const PdfMarkupToolbar({
    super.key,
    required this.controller,
    required this.viewerController,
    this.imagePicker,
  });

  final PdfEditingController controller;
  final PdfViewerController viewerController;
  final PdfImagePicker? imagePicker;

  PdfMarkupShortcut _shortcut() => PdfMarkupShortcut(
    onChooseTool: (tool) => controller.tool = tool,
    fingerDrawsInk: controller.preferences.fingerDrawsInk,
    onFingerDrawChanged: (enabled) =>
        controller.preferences.fingerDrawsInk = enabled,
  );

  Widget _insertImageButton() => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final active = controller.tool == PdfEditTool.image;
      return Semantics(
        button: true,
        selected: active,
        label: 'Insert Image',
        hint: 'Then tap or drag on the PDF page to place the image',
        child: FilledButton.tonalIcon(
          key: const Key('pdf-insert-image'),
          onPressed: imagePicker == null
              ? null
              : () => controller.tool = PdfEditTool.image,
          style: active
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                )
              : null,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
          label: const Text('Insert Image'),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < PdfEditingToolbar.mobileBreakpoint;
    final toolbar = PdfEditingToolbar(
      controller: controller,
      viewerController: viewerController,
      compact: compact,
      imagePicker: imagePicker,
      leading: compact
          ? const []
          : [
              (context, controller, viewerController) => _shortcut(),
              if (imagePicker != null)
                (context, controller, viewerController) => _insertImageButton(),
            ],
    );
    if (!compact) return toolbar;

    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('pdf-markup-shortcut-row'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _shortcut(),
                if (imagePicker != null) _insertImageButton(),
              ],
            ),
          ),
          toolbar,
        ],
      ),
    );
  }
}

class _PdfMarkupShortcutState extends State<PdfMarkupShortcut> {
  late bool _fingerDrawsInk = widget.fingerDrawsInk;

  @override
  void didUpdateWidget(covariant PdfMarkupShortcut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fingerDrawsInk != widget.fingerDrawsInk) {
      _fingerDrawsInk = widget.fingerDrawsInk;
    }
  }

  void _choose(_MarkupChoice choice) {
    switch (choice) {
      case _MarkupChoice.pen:
        widget.onChooseTool(PdfEditTool.ink);
      case _MarkupChoice.highlighter:
        widget.onChooseTool(PdfEditTool.highlight);
      case _MarkupChoice.eraser:
        widget.onChooseTool(PdfEditTool.eraser);
      case _MarkupChoice.textBox:
        widget.onChooseTool(PdfEditTool.freeText);
      case _MarkupChoice.select:
        widget.onChooseTool(PdfEditTool.select);
      case _MarkupChoice.fingerDrawing:
        setState(() => _fingerDrawsInk = !_fingerDrawsInk);
        widget.onFingerDrawChanged(_fingerDrawsInk);
    }
  }

  PopupMenuItem<_MarkupChoice> _item(
    _MarkupChoice action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_MarkupChoice>(
      value: action,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<_MarkupChoice>(
      key: const Key('pdf-markup-shortcut'),
      tooltip: 'Markup tools: pen, highlighter, eraser, and text box',
      onSelected: _choose,
      itemBuilder: (_) => [
        _item(_MarkupChoice.pen, Icons.draw_outlined, 'Pen / Draw'),
        _item(
          _MarkupChoice.highlighter,
          Icons.border_color_outlined,
          'Highlighter',
        ),
        _item(_MarkupChoice.eraser, Icons.auto_fix_off, 'Eraser'),
        _item(_MarkupChoice.textBox, Icons.text_fields, 'Text box'),
        _item(_MarkupChoice.select, Icons.open_with, 'Select / Move'),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<_MarkupChoice>(
          key: const Key('pdf-finger-drawing-choice'),
          value: _MarkupChoice.fingerDrawing,
          checked: _fingerDrawsInk,
          child: const Text('Draw with finger'),
        ),
      ],
      child: Semantics(
        button: true,
        label: 'Markup tools',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.draw_outlined,
                  size: 19,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  'Markup',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: colors.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
