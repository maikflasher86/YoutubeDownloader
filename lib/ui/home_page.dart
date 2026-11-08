import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'app_state.dart';
import 'batch_page.dart';
import 'link_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

/// Main screen: YouTube search and the download queue.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _tab = 0;

  /// Opens the link page and loads the video, used for shared links.
  void openLink(String text) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute<void>(builder: (_) => LinkPage(initialLink: text)),
    );
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final downloads = context.watch<AppState>().downloads;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YouTube Downloader',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        actions: [
          IconButton(
            key: const Key('linkButton'),
            tooltip: l.linkTitle,
            icon: const Icon(Icons.link),
            onPressed: () => _push(const LinkPage()),
          ),
          IconButton(
            key: const Key('batchButton'),
            tooltip: l.batchDownload,
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _push(const BatchPage()),
          ),
          IconButton(
            key: const Key('settingsButton'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(const SettingsPage()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const SearchPage(),
          downloads.isEmpty
              ? Center(child: Text(l.downloads))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [for (final d in downloads) DownloadTile(item: d)],
                ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            key: const Key('tabSearch'),
            icon: const Icon(Icons.search),
            label: l.search,
          ),
          NavigationDestination(
            key: const Key('tabDownloads'),
            icon: Badge(
              isLabelVisible: downloads.isNotEmpty,
              label: Text('${downloads.length}'),
              child: const Icon(Icons.download),
            ),
            label: l.downloads,
          ),
        ],
      ),
    );
  }
}
