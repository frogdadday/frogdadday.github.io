import 'package:flutter_test/flutter_test.dart';
import 'package:sean_johnston/models/countdown_spinner_session.dart';
import 'package:sean_johnston/models/spinner_model.dart';

void main() {
  test('countdown foundation snapshots a spinner without changing it', () {
    final source = spinnerTemplates.first;
    final session = CountdownSpinnerSession.fromSpinner(
      id: 'countdown-1',
      spinner: source,
    );

    expect(session.sourceSpinnerId, source.id);
    expect(session.originalSlices, source.slices);
    expect(session.remainingSlices, source.slices);
    expect(session.eliminatedSlices, isEmpty);
    expect(session.remainingCount, source.slices.length);
    expect(session.hasWinner, isFalse);
    expect(() => session.remainingSlices.removeAt(0), throwsUnsupportedError);
    expect(source.slices, spinnerTemplates.first.slices);
  });
}
