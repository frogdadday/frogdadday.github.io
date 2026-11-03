// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/services/content_guard.dart';

void main() {
  test('support keywords match whole words', () {
    expect(ContentGuard.supportKeywordIn(const <String>['kill']), 'kill');
    expect(ContentGuard.supportKeywordIn(const <String>['SKILL TEST']), isNull);
    expect(
      ContentGuard.supportKeywordIn(const <String>['self-harm']),
      'self harm',
    );
  });

  test('ordinary odd input does not trigger the support note', () {
    expect(ContentGuard.supportKeywordIn(const <String>['???']), isNull);
    expect(
      ContentGuard.needsFriendlyWarning('', const <String>['A', 'B']),
      isTrue,
    );
    expect(
      ContentGuard.needsFriendlyWarning('Dinner', const <String>['A', 'a']),
      isTrue,
    );
  });
}
