// /////Block One/////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

class CleanerCleanPage extends StatelessWidget {
  const CleanerCleanPage({
    super.key,
    required this.allFilesAccess,
    required this.roots,
    required this.busy,
    required this.cacheAutomationActive,
    required this.onAddFolder,
    required this.onRequestFullAnalysis,
    required this.onScan,
    required this.onOpenManageApps,
    required this.onClearOwnCache,
    required this.onClearAnotherAppCache,
    required this.onChooseAutoCacheApps,
    required this.onStopAutoCacheApps,
  });

  final bool allFilesAccess;
  final List<Map<Object?, Object?>> roots;
  final bool busy;
  final bool cacheAutomationActive;
  final VoidCallback onAddFolder;
  final VoidCallback onRequestFullAnalysis;
  final VoidCallback onScan;
  final VoidCallback onOpenManageApps;
  final VoidCallback onClearOwnCache;
  final VoidCallback onClearAnotherAppCache;
  final VoidCallback onChooseAutoCacheApps;
  final VoidCallback onStopAutoCacheApps;

  // /////Block Two///////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Clean', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Review storage and use Android’s own tools to manage apps and temporary files.',
        ),
        const SizedBox(height: 8),
        const Text(
          'A normal scan reads file names, sizes, and dates. Previews and duplicate checking read file contents locally. Nothing is uploaded.',
        ),
        _heading(
          context,
          allFilesAccess ? 'Full device analysis' : 'Choose where frog looks',
        ),
        Text(
          allFilesAccess
              ? 'Full device analysis covers shared storage. Android still protects other apps’ private data and protected Android folders.'
              : 'Choose a subfolder inside internal storage or an SD card. Android rejects the storage root, the Downloads root, and protected folders such as Android/data. For a broader shared-storage scan, enable Full device analysis.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            if (!allFilesAccess)
              FilledButton.icon(
                onPressed: busy ? null : onAddFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Choose a subfolder'),
              ),
            if (!allFilesAccess)
              OutlinedButton.icon(
                onPressed: busy ? null : onRequestFullAnalysis,
                icon: const Icon(Icons.folder_special_outlined),
                label: const Text('Enable full analysis'),
              ),
            OutlinedButton.icon(
              onPressed: busy || (!allFilesAccess && roots.isEmpty)
                  ? null
                  : onScan,
              icon: const Icon(Icons.search),
              label: Text(
                allFilesAccess ? 'Scan shared storage' : 'Scan folders',
              ),
            ),
            if (allFilesAccess)
              TextButton.icon(
                onPressed: busy ? null : onRequestFullAnalysis,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Manage access'),
              ),
          ],
        ),
        if (!allFilesAccess)
          ...roots.map(
            (root) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(root['label'] as String),
              subtitle: Text(
                root['readable'] == true
                    ? 'Access granted'
                    : 'Access lost — choose folder again',
              ),
            ),
          ),
        _sectionDivider(context),
        _heading(context, 'App controls'),
        const Text(
          'Open Android’s app controls to uninstall apps you no longer use, disable supported preinstalled apps, clear cache, or review permissions. Frog Cleaner does not change apps from this screen; optional cache automation is explained separately below.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onOpenManageApps,
          icon: const Icon(Icons.apps_outlined),
          label: const Text('Open Android app controls'),
        ),
        _sectionDivider(context),
        _heading(context, 'Temporary files and cache'),
        const Text(
          'Clear Frog Cleaner preview files here. Android manages each other app’s cache from that app’s own controls page.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onClearOwnCache,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Clear Frog Cleaner temporary files'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onClearAnotherAppCache,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Clear another app’s cache'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy || cacheAutomationActive
              ? null
              : onChooseAutoCacheApps,
          icon: const Icon(Icons.auto_mode_outlined),
          label: const Text('Automatically clear selected app caches'),
        ),
        if (cacheAutomationActive) ...<Widget>[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy ? null : onStopAutoCacheApps,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop automatic cache cleaning'),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Compatibility varies by Android version and device maker. If Android Settings uses an unrecognized layout or wording, Frog Cleaner skips that app instead of guessing.',
        ),
        _sectionDivider(context),
        _heading(context, 'Tips for safe cleaning'),
        const Text(
          '• Large files are not necessarily unnecessary.\n'
          '• Old files are not necessarily unused.\n'
          '• Android Trash is reversible for a limited time.\n'
          '• Permanent deletion cannot be undone.',
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _sectionDivider(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Divider(
      height: 2,
      thickness: 2,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.72),
    ),
  );
}
