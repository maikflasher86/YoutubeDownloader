import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:saf_util/saf_util.dart';

import '../l10n/app_localizations.dart';
import '../models/video_quality.dart';
import '../services/app_settings.dart';
import '../services/desktop_services.dart';

/// Lets the user choose the download folder.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.pickFolder});

  /// Replaceable in tests; returns (treeUri, name) or null when cancelled.
  final Future<(String, String)?> Function()? pickFolder;

  Future<(String, String)?> _pick() async {
    if (isDesktop) {
      final path = await FilePicker.getDirectoryPath();
      return path == null ? null : (path, p.basename(path));
    }
    final dir = await SafUtil().pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    return dir == null ? null : (dir.uri, dir.name);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final name = settings.folderName;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            key: const Key('folderTile'),
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.downloadFolder),
            subtitle: Text(
              name == null ? l.defaultFolders : l.folderSubtitle(name),
            ),
            isThreeLine: name != null,
            onTap: () async {
              final picked = await (pickFolder ?? _pick)();
              if (picked != null) {
                await settings.setFolder(picked.$1, picked.$2);
              }
            },
          ),
          if (name != null)
            ListTile(
              key: const Key('resetFolder'),
              leading: const Icon(Icons.restore),
              title: Text(l.useDefaultFolders),
              onTap: settings.resetFolder,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text(l.defaultVideoQuality),
            trailing: DropdownButton<VideoQuality>(
              key: const Key('defaultQuality'),
              value: settings.videoQuality,
              items: [
                for (final q in VideoQuality.values)
                  DropdownMenuItem(value: q, child: Text(q.label)),
              ],
              onChanged: (q) {
                if (q != null) settings.setVideoQuality(q);
              },
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('imprintTile'),
            leading: const Icon(Icons.info_outline),
            title: Text(l.imprint),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImprintPage()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legal notice: developer and permitted use.
class ImprintPage extends StatelessWidget {
  const ImprintPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.imprint)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.developer, style: theme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Maik Neumann',
            key: const Key('imprintDeveloper'),
            style: theme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(l.usage, style: theme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l.usageText,
            key: const Key('imprintUsage'),
            style: theme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(l.version, style: theme.titleMedium),
          const SizedBox(height: 4),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Text(
              snap.data?.version ?? '',
              key: const Key('imprintVersion'),
              style: theme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
