import 'spinner_model.dart';

/// A future countdown run derived from a saved spinner.
///
/// This model deliberately owns snapshots of the source and working slice
/// lists. Countdown progress can therefore be saved independently without
/// mutating the original [SpinnerModel]. It is not wired into storage or the
/// spinning interface yet.
class CountdownSpinnerSession {
  CountdownSpinnerSession({
    required this.id,
    required this.sourceSpinnerId,
    required this.title,
    required List<String> originalSlices,
    required List<String> remainingSlices,
    List<String> eliminatedSlices = const <String>[],
    required this.colorValue,
    required this.scheme,
    this.category = '',
  }) : originalSlices = List<String>.unmodifiable(originalSlices),
       remainingSlices = List<String>.unmodifiable(remainingSlices),
       eliminatedSlices = List<String>.unmodifiable(eliminatedSlices) {
    if (id.trim().isEmpty ||
        sourceSpinnerId.trim().isEmpty ||
        originalSlices.length < 2 ||
        remainingSlices.isEmpty ||
        remainingSlices.length > originalSlices.length) {
      throw const FormatException('Invalid countdown spinner session');
    }
  }

  factory CountdownSpinnerSession.fromSpinner({
    required String id,
    required SpinnerModel spinner,
  }) {
    return CountdownSpinnerSession(
      id: id,
      sourceSpinnerId: spinner.id,
      title: spinner.title,
      originalSlices: spinner.slices,
      remainingSlices: spinner.slices,
      colorValue: spinner.colorValue,
      scheme: spinner.scheme,
      category: spinner.category,
    );
  }

  final String id;
  final String sourceSpinnerId;
  final String title;
  final List<String> originalSlices;
  final List<String> remainingSlices;
  final List<String> eliminatedSlices;
  final int colorValue;
  final WheelScheme scheme;
  final String category;

  int get remainingCount => remainingSlices.length;
  int get eliminatedCount => eliminatedSlices.length;
  bool get hasWinner => remainingSlices.length == 1;
}
