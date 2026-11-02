import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimerDurationDialog extends StatefulWidget {
  final int initialMinutes;
  const TimerDurationDialog({super.key, required this.initialMinutes});

  @override
  State<TimerDurationDialog> createState() => _TimerDurationDialogState();
}

class _TimerDurationDialogState extends State<TimerDurationDialog> {
  final form = GlobalKey<FormState>();
  late final controller = TextEditingController(
    text: '${widget.initialMinutes}',
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('How many minutes?'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            labelText: 'Minutes',
            helperText: 'Choose from 1 to 1,440 minutes (24 hours).',
            helperMaxLines: 8,
            errorMaxLines: 8,
          ),
          validator: (text) {
            final value = int.tryParse(text ?? '');
            return value == null || value < 1 || value > 1440
                ? 'Enter a number from 1 to 1,440.'
                : null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final state = form.currentState;
          final value = int.tryParse(controller.text);
          if (state != null && state.validate() && value != null) {
            Navigator.pop(context, value);
          }
        },
        child: const Text('Use this time'),
      ),
    ],
  );
}
