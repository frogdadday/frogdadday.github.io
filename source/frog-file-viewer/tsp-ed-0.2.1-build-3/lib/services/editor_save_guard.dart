/// Identifies exactly which editor document and revision a save captured.
///
/// A successful file-picker write may complete after a newer edit has arrived.
/// Such a save is still a valid copy of its captured bytes, but must not mark
/// the current editor clean or delete the newer unsaved recovery checkpoint.
final class EditorSaveSnapshot {
  const EditorSaveSnapshot(this.documentGeneration, this.editRevision);

  final int documentGeneration;
  final int editRevision;
}

final class EditorSaveGuard {
  int _documentGeneration = 0;
  int _editRevision = 0;

  void openedDocument() {
    _documentGeneration++;
    _editRevision = 0;
  }

  void recordedEdit() {
    _editRevision++;
  }

  EditorSaveSnapshot capture() =>
      EditorSaveSnapshot(_documentGeneration, _editRevision);

  bool isStillCurrent(EditorSaveSnapshot snapshot) =>
      snapshot.documentGeneration == _documentGeneration &&
      snapshot.editRevision == _editRevision;
}
