// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import 'storage.dart';

class StorageMapPage extends StatelessWidget {
  const StorageMapPage({
    super.key,
    required this.scanned,
    required this.files,
    required this.path,
    required this.onUp,
    required this.onOpenFiles,
    required this.onOpenFolder,
  });

  final bool scanned;
  final List<StorageFile> files;
  final List<String> path;
  final VoidCallback onUp;
  final ValueChanged<List<String>> onOpenFiles;
  final ValueChanged<List<String>> onOpenFolder;

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final summaries = folderSummaries(files, path);
    final title = path.isEmpty ? 'Scanned storage' : path.join(' / ');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Storage Map', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Largest folders first, based on the files in your latest scan. A folder size includes files inside its subfolders.',
        ),
        if (!scanned) ...<Widget>[
          const SizedBox(height: 24),
          const Text('Run a scan from Clean to build your storage map.'),
        ] else ...<Widget>[
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (path.isNotEmpty)
            TextButton.icon(
              onPressed: onUp,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Up one folder'),
            ),
          if (summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No scanned files are inside this folder.'),
            ),
          ...summaries.map(
            (summary) => Card(
              child: ListTile(
                leading: Icon(
                  summary.directFiles
                      ? Icons.insert_drive_file_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(summary.name),
                subtitle: Text(
                  '${summary.fileCount} ${summary.fileCount == 1 ? 'file' : 'files'}'
                  '${summary.unknownSizeCount == 0 ? '' : ' • ${summary.unknownSizeCount} unknown size'}',
                ),
                trailing: Text(bytes(summary.bytes)),
                onTap: summary.directFiles
                    ? () => onOpenFiles(summary.path)
                    : () => onOpenFolder(summary.path),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A larger folder is not automatically a problem. Open it and review its files before removing anything.',
          ),
        ],
      ],
    );
  }
}
