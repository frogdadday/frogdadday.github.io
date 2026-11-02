// Block One////////////////////////////////////////////////////////

import 'package:flutter/material.dart';
import 'dart:math';

import '../conversion_engine.dart';
import 'frog_widget.dart';
import 'dialog_queue.dart';

/// ------------------------------------------------------------
/// ENUMS & TYPES
/// ------------------------------------------------------------

/// Tone categories for dialog variants.
enum EggTone { playful, nerdy, dramatic, cosmic }

/// Reaction types mapped to frog animations.
enum FrogReactionType {
  neutralBlink,
  doubleBlink,
  wink,
  lightning,
  freeze,
  flash,
}

/// ------------------------------------------------------------
/// COSMIC DIALOG (Deep Space Glow)
/// ------------------------------------------------------------

class CosmicDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final Widget? image;

  const CosmicDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = "OK",
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2A0A4A), // deep purple
              Color(0xFF0A1A4A), // cosmic blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.6),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null) ...[
                SizedBox(height: 8),
                image!,
                SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.blueAccent, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.35,
                  shadows: [Shadow(color: Colors.blueAccent, blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Block Two///////////////////////////////////////////////////////////////
// Unit categories and category detection now live in conversion_engine.dart.

// Block Three/////////////////////////////////////////////////////////////
/// ------------------------------------------------------------
/// DIALOG TEMPLATES (randomized variants by tone)
/// ------------------------------------------------------------

final Map<EggTone, List<String>> toneOpeners = {
  EggTone.playful: [
    "Hey, check this out!",
    "Fun fact incoming!",
    "Guess what?",
    "You triggered something fun!",
  ],
  EggTone.nerdy: [
    "Scientific anomaly detected:",
    "Data spike observed:",
    "Nerd alert:",
    "Statistically improbable event:",
  ],
  EggTone.dramatic: [
    "Behold!",
    "A moment of destiny:",
    "The universe trembles:",
    "Brace yourself:",
  ],
  EggTone.cosmic: [
    "Across the cosmic void…",
    "A shimmer in spacetime whispers:",
    "The stars align and say:",
    "Reality bends softly:",
  ],
};

/// Specific easter-egg messages
final Map<String, List<String>> eggMessages = {
  "42": [
    "42 — the answer to life, the universe, and everything.",
    "Ah, 42. A number with cosmic significance.",
    "You found 42. The universe nods approvingly.",
  ],
  "13": [
    "Thirteen detected. Superstition levels are rising.",
    "Lucky or unlucky? The cosmos refuses to take sides.",
    "You found 13. The frog is tossing salt over its shoulder for some weird reason.",
  ],
  "speed_of_light": [
    "You've reached the speed of light. Time dilation intensifies.",
    "299,792,458 m/s — spacetime is impressed.",
    "Careful! At light speed, mass and time get weird.",
  ],
  "absolute_zero": [
    "Absolute zero. Motion ceases. Even the frog shivers.",
    "0 Kelvin — the coldest possible temperature.",
    "You've hit absolute zero. Reality freezes.",
  ],
  "heat_death": [
    "The universe grows cold and dim… heat death approaches.",
    "Entropy wins in the end. Even frogs cannot escape.",
    "A future without stars. A quiet cosmic sigh.",
  ],
  "planck_scale": [
    "You've reached the Planck scale — the fabric of reality jitters.",
    "Planck units detected. Quantum foam ripples.",
    "At this scale, spacetime becomes grainy and strange.",
  ],
  "water_density": [
    "1 g/mL — the density of water. Hydration achieved.",
    "Water density detected. The frog approves.",
    "Perfectly balanced, like water itself.",
  ],
  "digital_storage": [
    "Converting digital storage? Bits and bytes dance.",
    "A byte-sized cosmic event.",
    "Your data ripples through the void.",
  ],
  "parsec_unlock": [
    "A parsec! You’ve unlocked cosmic navigation.",
    "Interstellar distances bow before you.",
    "The stars whisper: 'Navigator acknowledged.'",
  ],
};

/// ------------------------------------------------------------
/// RANDOM HELPERS
/// ------------------------------------------------------------

final Random _rng = Random();

String randomFrom(List<String> list) => list[_rng.nextInt(list.length)];

EggTone randomTone() {
  final tones = EggTone.values;
  return tones[_rng.nextInt(tones.length)];
}

/// Build a full dialog message from tone + egg key.
String buildDialogMessage(EggTone tone, String eggKey) {
  final opener = randomFrom(toneOpeners[tone]!);
  final body = randomFrom(eggMessages[eggKey]!);
  return "$opener\n\n$body";
}

/// ------------------------------------------------------------
/// FLOATING-POINT COMPARISON HELPER
/// ------------------------------------------------------------

bool _nearlyEqual(double a, double b, {double tolerance = 1e-9}) {
  final scale = max(1.0, max(a.abs(), b.abs()));
  return (a - b).abs() <= tolerance * scale;
}

/// ------------------------------------------------------------
/// FROG REACTION MAPPER
/// ------------------------------------------------------------

void triggerFrogReaction(FrogWidgetState? frog, FrogReactionType type) {
  if (frog == null) return;

  switch (type) {
    case FrogReactionType.neutralBlink:
      frog.triggerNeutralBlink(duration: const Duration(milliseconds: 1100));
      break;
    case FrogReactionType.doubleBlink:
      frog.triggerDoubleBlink();
      break;
    case FrogReactionType.wink:
      frog.triggerWink();
      break;
    case FrogReactionType.lightning:
      frog.triggerLightning();
      break;
    case FrogReactionType.freeze:
      frog.triggerFreezeBlink(const Duration(milliseconds: 800));
      break;
    case FrogReactionType.flash:
      frog.triggerFlash();
      break;
  }
}

// Block Four /////////////////////////////////////////////////////////////////
/// ------------------------------------------------------------
/// EASTER-EGG TRIGGER ENGINE
/// ------------------------------------------------------------

/// Internal helper to show a cosmic dialog + frog reaction.
void _showEgg({
  required BuildContext context,
  required FrogWidgetState? frog,
  required String eggKey,
  required FrogReactionType reaction,
}) {
  final tone = randomTone();
  final message = buildDialogMessage(tone, eggKey);

  VoidCallback? onShown;
  VoidCallback? onDismissed;

  if (reaction == FrogReactionType.freeze) {
    onShown = () {
      frog?.setFrozen(true);
    };
    onDismissed = () {
      frog?.setFrozen(false);
    };
  } else if (eggKey == "heat_death") {
    onShown = () {
      frog?.triggerHeatDeath();
    };
    onDismissed = () {
      frog?.endHeatDeath();
    };
  } else if (eggKey == "parsec_unlock") {
    // Give parsec its own deliberate flash duration.
    onShown = () {
      frog?.triggerFlash(duration: const Duration(milliseconds: 1200));
    };
  } else {
    onShown = () {
      triggerFrogReaction(frog, reaction);
    };
  }

  DialogQueue.instance.enqueue(
    context: context,
    builder: (context) => CosmicDialog(
      title: eggKey.replaceAll("_", " ").toUpperCase(),
      message: message,
    ),
    onShown: onShown,
    onDismissed: onDismissed,
    dedupeKey: "easter_egg:$eggKey",
  );
}

// Block Five /////////////////////////////////////////////////////////////////
/// ------------------------------------------------------------
/// FINAL WRAPPER
/// ------------------------------------------------------------

bool checkEasterEggs({
  required BuildContext context,
  required FrogWidgetState? frog,
  required String fromUnit,
  required String toUnit,
  required double inputValue,
  required double resultValue,
}) {
  // Normalize units once
  final uFrom = fromUnit.trim().toLowerCase();
  final uTo = toUnit.trim().toLowerCase();

  // Primary triggers
  if (_primaryEggs(
    context: context,
    frog: frog,
    fromUnit: uFrom,
    toUnit: uTo,
    inputValue: inputValue,
    resultValue: resultValue,
  )) {
    return true;
  }

  // Additional triggers
  if (_checkAdditionalEggs(
    context: context,
    frog: frog,
    fromUnit: uFrom,
    toUnit: uTo,
    inputValue: inputValue,
    resultValue: resultValue,
  )) {
    return true;
  }

  return false;
}

/// Primary easter-egg triggers.
bool _primaryEggs({
  required BuildContext context,
  required FrogWidgetState? frog,
  required String fromUnit, // now normalized
  required String toUnit, // now normalized
  required double inputValue,
  required double resultValue,
}) {
  bool isAbsoluteZero(double value, String unit) {
    switch (unit) {
      case 'kelvin':
      case 'planck_temperature':
        return _nearlyEqual(value, 0);
      case 'celsius':
        return _nearlyEqual(value, -273.15);
      case 'fahrenheit':
        return _nearlyEqual(value, -459.67);
      default:
        return false;
    }
  }

  // 1. 42? No... The answer is always 42 2. 13? Bad luck.
  if (_nearlyEqual(inputValue, 42) || _nearlyEqual(resultValue, 42)) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "42",
      reaction: FrogReactionType.wink,
    );
    return true;
  }

  // 2. 13? Bad luck.
  if (_nearlyEqual(inputValue, 13) || _nearlyEqual(resultValue, 13)) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "13",
      reaction: FrogReactionType.doubleBlink,
    );
    return true;
  }

  // 3. Speed of light
  if (fromUnit == 'speed_of_light' ||
      toUnit == 'speed_of_light' ||
      ((fromUnit == 'mps' || toUnit == 'mps') &&
          (_nearlyEqual(inputValue, 299792458) ||
              _nearlyEqual(resultValue, 299792458)))) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "speed_of_light",
      reaction: FrogReactionType.lightning,
    );
    return true;
  }

  // Tiny positive Kelvin values must take priority over the approximate
  // absolute-zero comparison (including rounded Celsius/Fahrenheit results).
  final nearHeatDeathInput =
      fromUnit == 'kelvin' && inputValue > 0 && inputValue < 1e-12;
  final nearHeatDeathResult =
      toUnit == 'kelvin' && resultValue > 0 && resultValue < 1e-12;
  if (nearHeatDeathInput || nearHeatDeathResult) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "heat_death",
      reaction: FrogReactionType.flash,
    );
    return true;
  }

  // 4. Absolute zero
  if (isAbsoluteZero(inputValue, fromUnit) ||
      isAbsoluteZero(resultValue, toUnit)) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "absolute_zero",
      reaction: FrogReactionType.freeze,
    );
    return true;
  }

  // 6. Planck scale
  if (fromUnit.startsWith("planck_") || toUnit.startsWith("planck_")) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "planck_scale",
      reaction: FrogReactionType.doubleBlink,
    );
    return true;
  }

  return false;
}

bool _checkAdditionalEggs({
  required BuildContext context,
  required FrogWidgetState? frog,
  required String fromUnit, // now normalized
  required String toUnit, // now normalized
  required double inputValue,
  required double resultValue,
}) {
  final fromCat = detectCategory(fromUnit);
  final toCat = detectCategory(toUnit);

  // 7. Water density (1 g/mL or 1 kg/L)
  final isGramMilliliter =
      (fromUnit == 'g' && toUnit == 'ml') ||
      (fromUnit == 'ml' && toUnit == 'g');

  final isKilogramLiter =
      (fromUnit == 'kg' && toUnit == 'l') ||
      (fromUnit == 'l' && toUnit == 'kg');

  if ((isGramMilliliter || isKilogramLiter) &&
      (_nearlyEqual(inputValue, 1) || _nearlyEqual(resultValue, 1))) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "water_density",
      reaction: FrogReactionType.neutralBlink,
    );
    return true;
  }

  // 8. Digital storage jokes
  if (fromCat == 'digital_storage' || toCat == 'digital_storage') {
    if (_nearlyEqual(inputValue, 1024) || _nearlyEqual(resultValue, 1024)) {
      _showEgg(
        context: context,
        frog: frog,
        eggKey: "digital_storage",
        reaction: FrogReactionType.wink,
      );
      return true;
    }
  }

  // 9. Parsec unlock (cosmic distance)
  const parsecThresholds = {
    'mm': 3.085677581e19,
    'cm': 3.085677581e18,
    'm': 3.085677581e16,
    'km': 3.085677581e13,
    'in': 1.214833693e18,
    'ft': 1.012361411e17,
    'yd': 3.374538035e16,
    'mi': 1.917351157e13,
    'lightyear': 3.261563777,
  };

  final fromParsecThreshold = parsecThresholds[fromUnit];
  final toParsecThreshold = parsecThresholds[toUnit];

  final parsecScaleInput =
      fromCat == 'length' &&
      fromParsecThreshold != null &&
      inputValue >= fromParsecThreshold;

  final parsecScaleResult =
      toCat == 'length' &&
      toParsecThreshold != null &&
      resultValue >= toParsecThreshold;

  if (parsecScaleInput || parsecScaleResult) {
    _showEgg(
      context: context,
      frog: frog,
      eggKey: "parsec_unlock",
      reaction: FrogReactionType.flash,
    );
    return true;
  }

  return false;
}
