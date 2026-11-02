import 'storage.dart';

class UIStateController {
  int page = 0;
  bool cosmicMode = false;
  List<String> mapPath = [];
  List<String>? fileFolderFilter;
  String filter = 'All';
  String search = '';
  bool duplicateView = false;
  bool downloadsView = false;
  String downloadFilter = 'All';
  bool showOnlyDeletableMedia = false;

  void resetFileViews() {
    duplicateView = false;
    downloadsView = false;
    fileFolderFilter = null;
    mapPath = [];
  }

  List<StorageFile> visibleFiles(Iterable<StorageFile> files) => files
      .where(
        (file) =>
            (search.isEmpty ||
                '${file.name} ${file.location}'.toLowerCase().contains(
                  search.toLowerCase(),
                )) &&
            (fileFolderFilter == null || isInFolder(file, fileFolderFilter!)) &&
            (filter == 'All' ||
                filter == file.category ||
                filter == 'Large' && (file.size ?? 0) >= 100 * 1024 * 1024 ||
                filter == 'Old' && file.oldAt(DateTime.now())) &&
            (!showOnlyDeletableMedia ||
                file.canDelete &&
                    const [
                      'Photos',
                      'Videos',
                      'Audio',
                    ].contains(file.category)),
      )
      .toList();
}
