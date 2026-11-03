import 'package:flutter/material.dart';

import '../models/spinner_model.dart';
import '../theme/app_theme.dart';
import 'spinner_wheel.dart';

class SchemePicker extends StatelessWidget {
  const SchemePicker({
    super.key,
    required this.spinner,
    required this.enabled,
    required this.onSchemeChanged,
    required this.onColorChanged,
  });

  final SpinnerModel spinner;
  final bool enabled;
  final ValueChanged<WheelScheme> onSchemeChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wheel colors',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Tap a look for your wheel.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WheelScheme.values.map((scheme) {
            final selected = spinner.scheme == scheme;
            final sample = spinner.copyWith(
              scheme: scheme,
              slices: List.filled(6, ''),
            );
            return Semantics(
              button: true,
              selected: selected,
              label: scheme.label,
              enabled: enabled,
              onTap: enabled ? () => onSchemeChanged(scheme) : null,
              child: ExcludeSemantics(
                child: InkWell(
                  key: Key('scheme-${scheme.name}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled ? () => onSchemeChanged(scheme) : null,
                  child: Container(
                    width: 82,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFFDC45)
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 48,
                              child: SpinnerWheel(
                                spinner: sample,
                                showLabels: false,
                              ),
                            ),
                            if (selected)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheme.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.frogYellow),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Center(
          child: SizedBox.square(
            dimension: 140,
            child: SpinnerWheel(
              key: const Key('scheme-preview'),
              spinner: spinner,
            ),
          ),
        ),
        if (spinner.scheme == WheelScheme.classic) ...[
          const SizedBox(height: 12),
          const Text('Choose a color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(spinnerPalette.length, (index) {
              final color = spinnerPalette[index];
              final selected = spinner.colorValue == color.toARGB32();
              const names = [
                'Red',
                'Orange',
                'Yellow',
                'Green',
                'Teal',
                'Blue',
                'Indigo',
                'Purple',
                'Pink',
                'Brown',
              ];
              return Semantics(
                button: true,
                selected: selected,
                label: names[index],
                enabled: enabled,
                onTap: enabled ? () => onColorChanged(color) : null,
                child: ExcludeSemantics(
                  child: InkWell(
                    key: Key('classic-color-$index'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: enabled ? () => onColorChanged(color) : null,
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.black,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.179
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            names[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.frogYellow),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
