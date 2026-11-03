import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import 'labeled_icon_button.dart';

Future<void> showChoicesSheet(BuildContext context, SpinnerModel spinner) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.8,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All ${spinner.slices.length} choices',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  LabeledIconButton(
                    label: 'Close',
                    tooltip: 'Close choices',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                key: const Key('choices-list'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: spinner.slices.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, index) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: spinner.sliceColor(index),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: spinner.sliceTextColor(index),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        spinner.slices[index].trim().isEmpty
                            ? '(blank)'
                            : spinner.slices[index],
                        key: Key('choice-full-$index'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
