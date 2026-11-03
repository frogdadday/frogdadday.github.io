// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

@immutable
class AppModeTheme extends ThemeExtension<AppModeTheme> {
  const AppModeTheme({required this.cosmic});

  final bool cosmic;

  @override
  AppModeTheme copyWith({bool? cosmic}) =>
      AppModeTheme(cosmic: cosmic ?? this.cosmic);

  @override
  AppModeTheme lerp(AppModeTheme? other, double t) =>
      t < 0.5 ? this : other ?? this;
}

// /////Block Two/////////////////////////////////////////////////////////////
abstract final class CosmicCopy {
  static String forMode(String text, {required bool cosmic}) {
    if (!cosmic) return text;
    final protectedTitles = <String>[];
    var result = text.replaceAllMapped(
      RegExp('Cosmic Chores', caseSensitive: false),
      (match) {
        protectedTitles.add(match.group(0)!);
        return '\u0000COSMIC_CHORES_TITLE_${protectedTitles.length - 1}\u0000';
      },
    );
    for (final replacement in const <(String, String)>[
      ('chores', 'missions'),
      ('chore', 'mission'),
      ('people', 'crewmembers'),
      ('person', 'crewmember'),
      ('owners', 'captains'),
      ('owner', 'captain'),
      ('developers', 'captains'),
      ('developer', 'captain'),
    ]) {
      result = result.replaceAllMapped(
        RegExp('\\b${replacement.$1}\\b', caseSensitive: false),
        (match) => _matchCase(match.group(0)!, replacement.$2),
      );
    }
    for (var index = 0; index < protectedTitles.length; index++) {
      result = result.replaceAll(
        '\u0000COSMIC_CHORES_TITLE_$index\u0000',
        protectedTitles[index],
      );
    }
    return result;
  }

  static String _matchCase(String source, String replacement) {
    if (source == source.toUpperCase()) return replacement.toUpperCase();
    if (source[0] == source[0].toUpperCase()) {
      return '${replacement[0].toUpperCase()}${replacement.substring(1)}';
    }
    return replacement;
  }
}

extension CosmicCopyContext on BuildContext {
  bool get isCosmicMode =>
      Theme.of(this).extension<AppModeTheme>()?.cosmic ?? false;

  String cosmicCopy(String text) =>
      CosmicCopy.forMode(text, cosmic: isCosmicMode);
}
