import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'app_state.dart';
import 'batch_page.dart';
import 'link_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _tab = 1;

  void openLink(String text) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute<void>(builder: (_) => LinkPage(initialLink: text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final downloads = context.watch<AppState>().downloads;
    final labels = [l.downloads, l.search, l.batchDownload, l.settings];
    final icons = [
      Icons.download_outlined,
      Icons.search,
      Icons.playlist_add,
      Icons.settings_outlined,
    ];
    final keys = [
      const Key('tabDownloads'),
      const Key('tabSearch'),
      const Key('batchButton'),
      const Key('settingsButton'),
    ];
    final content = IndexedStack(
      index: _tab,
      children: [
        const LinkPage(embedded: true),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.searchTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const Expanded(child: SearchPage()),
          ],
        ),
        BatchPage(onStarted: () => setState(() => _tab = 0)),
        const SettingsPage(embedded: true),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  Container(
                    width: 220,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 32, 24, 28),
                          child: Text(
                            'YouTube\nDownloader',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (var i = 0; i < labels.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            child: ListTile(
                              key: keys[i],
                              selected: _tab == i,
                              selectedTileColor: const Color(0xFF203153),
                              selectedColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(icons[i]),
                              title: Text(labels[i]),
                              onTap: () => setState(() => _tab = i),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Expanded(child: content),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                        key: keys[i],
                        icon: i == 0
                            ? Badge(
                                isLabelVisible: downloads.isNotEmpty,
                                label: Text('${downloads.length}'),
                                child: Icon(icons[i]),
                              )
                            : Icon(icons[i]),
                        label: labels[i],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
