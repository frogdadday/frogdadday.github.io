// ////Block One//////////////////////////////////////////////////////////////
class ContentGuard {
  ContentGuard._();

  // Local keyword matching only; it does not infer intent or block content.
  // Used only for an optional note after an explicit, successful wheel save.
  // Whole-word matching avoids matching "kill" inside "skill".
  static const List<String> _supportKeywords = <String>[
    'kill',
    'killing',
    'murder',
    'suicide',
    'self harm',
    'self-harm',
    'death',
    'die',
    'dying',
  ];

  static String? supportKeywordIn(Iterable<String> values) {
    for (final value in values) {
      final normalized = value
          .toLowerCase()
          .replaceAll(RegExp(r'[_\-]+'), ' ')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      for (final term in _supportKeywords) {
        final normalizedTerm = term.replaceAll('-', ' ');
        final expression = RegExp(
          '(^|\\s)${RegExp.escape(normalizedTerm)}(\\s|\$)',
        );
        if (expression.hasMatch(normalized)) return term;
      }
    }
    return null;
  }

  static bool needsFriendlyWarning(String title, List<String> slices) {
    if (title.trim().isEmpty || slices.any((slice) => slice.trim().isEmpty)) {
      return true;
    }
    final normalized = slices
        .map((slice) => slice.trim().toLowerCase())
        .toList();
    if (normalized.toSet().length != normalized.length) return true;
    return <String>[
      title,
      ...slices,
    ].any((value) => !RegExp(r'[a-zA-Z0-9]').hasMatch(value));
  }
}
