// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import 'cosmic_mode.dart';
import 'storage.dart';

class CleanerHomePage extends StatelessWidget {
  const CleanerHomePage({
    super.key,
    required this.cosmicMode,
    required this.total,
    required this.free,
    required this.scanned,
    required this.files,
    required this.allFilesAccess,
    required this.onOpenClean,
    required this.onReviewFiles,
  });

  final bool cosmicMode;
  final int? total;
  final int? free;
  final bool scanned;
  final List<StorageFile> files;
  final bool allFilesAccess;
  final VoidCallback onOpenClean;
  final VoidCallback onReviewFiles;

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'A little room\nto breathe.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text('Your files. Your choice.'),
                ],
              ),
            ),
            Semantics(
              label: 'Friendly frog mascot',
              image: true,
              child: SizedBox(
                width: 95,
                height: 100,
                child: CosmicFrog(cosmicMode: cosmicMode),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('INTERNAL STORAGE'),
              const SizedBox(height: 12),
              Text(
                total == null
                    ? 'Available on your Android device'
                    : '${bytes(total! - free!)} used of ${bytes(total!)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (total != null && total! > 0) ...<Widget>[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: ((total! - free!) / total!).clamp(0, 1),
                ),
                const SizedBox(height: 8),
                Text('${bytes(free!)} available'),
              ],
              const SizedBox(height: 12),
              const Text(
                'Device usage includes apps and system files that this scan cannot inspect.',
              ),
            ],
          ),
        ),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ready when you are',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose what to review, run a storage scan, or manage temporary files from Clean.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenClean,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Open Clean'),
              ),
            ],
          ),
        ),
        if (scanned)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${bytes(files.fold(0, (sum, file) => sum + (file.size ?? 0)))} in ${allFilesAccess ? 'shared-storage' : 'scanned'} files',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${files.length} files • ${files.where((file) => file.size == null).length} with unknown size',
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is analyzed storage, not a recommendation to delete it all.',
                ),
                TextButton(
                  onPressed: onReviewFiles,
                  child: const Text('Review files →'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Free. Simple. Respectful.\nNo ads. No accounts. No paid features.',
        ),
      ],
    );
  }

  Widget _panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}
