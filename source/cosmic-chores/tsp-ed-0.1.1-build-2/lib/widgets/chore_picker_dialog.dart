// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../data/chore_ideas.dart';
import '../services/cosmic_copy.dart';

class ChorePickerDialog extends StatefulWidget {
  const ChorePickerDialog({super.key});

  @override
  State<ChorePickerDialog> createState() => _ChorePickerDialogState();
}

class _ChorePickerDialogState extends State<ChorePickerDialog> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final matches = choreIdeas
        .where((idea) => query.isEmpty || idea.toLowerCase().contains(query))
        .toList();
    final custom = controller.text.trim();
    final exactMatch = choreIdeas.any(
      (idea) => idea.toLowerCase() == custom.toLowerCase(),
    );
    return AlertDialog(
      scrollable: true,
      title: Text(context.cosmicCopy('Choose or enter a chore')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.cosmicCopy('Search chores or type your own'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
            if (custom.isNotEmpty && !exactMatch)
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: Text('Use “$custom”'),
                onTap: () => Navigator.pop(context, custom),
              ),
            const Divider(height: 1),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(matches[index]),
                  onTap: () => Navigator.pop(context, matches[index]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
