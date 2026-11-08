import 'settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../services/app_settings.dart';
import 'app_state.dart';

const _bg = Color(0xFF0E0E12);
const _surface = Color(0xFF1A1A22);
const _accent = Color(0xFFFF3B5C);

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
    surface: _surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _controller = TextEditingController();

  /// Fills the field and loads the video, used for shared links.
  void openLink(String text) {
    _controller.text = text;
    context.read<AppState>().loadLink(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) openLink(data!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Downloader',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            key: const Key('settingsButton'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            key: const Key('urlField'),
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (v) => context.read<AppState>().loadLink(v),
            decoration: InputDecoration(
              hintText: 'Paste a YouTube link',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                key: const Key('pasteButton'),
                icon: const Icon(Icons.content_paste),
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('loadButton'),
            onPressed: state.loading
                ? null
                : () => context.read<AppState>().loadLink(_controller.text),
            icon: const Icon(Icons.search),
            label: const Text('Load video'),
          ),
          const SizedBox(height: 16),
          if (state.loading)
            const Center(child: CircularProgressIndicator())
          else if (state.error != null)
            Text(state.error!,
                key: const Key('errorText'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (state.video != null) _VideoCard(info: state.video!),
          if (state.downloads.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Downloads', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final d in state.downloads) _DownloadTile(item: d),
          ],
        ],
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({required this.info});
  final VideoInfo info;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  /// User choice for this session; falls back to the default from settings.
  int? _choice;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final state = context.read<AppState>();
    final quality = _choice ?? context.watch<AppSettings>().videoQuality;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              info.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black26,
                child: Icon(Icons.play_circle_outline, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title,
                    key: const Key('videoTitle'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [info.author, if (info.duration != null) _fmt(info.duration!)]
                      .join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Video quality'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      key: const Key('qualityDropdown'),
                      value: quality,
                      items: [
                        for (final q in videoQualities)
                          DropdownMenuItem(value: q, child: Text('${q}p')),
                      ],
                      onChanged: (q) => setState(() => _choice = q),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('mp3Button'),
                        onPressed: () => state.startDownload(DownloadKind.audio),
                        icon: const Icon(Icons.music_note),
                        label: const Text('MP3'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('videoButton'),
                        onPressed: () => state.startDownload(DownloadKind.video,
                            height: quality),
                        icon: const Icon(Icons.movie),
                        label: const Text('Video'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.status == DownloadStatus.done;
    final failed = item.status == DownloadStatus.failed;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: const Key('downloadTile'),
        onTap: done ? () => context.read<AppState>().open(item) : null,
        leading: Icon(item.kind == DownloadKind.audio
            ? Icons.music_note
            : Icons.movie),
        title: Text(item.info.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failed
                  ? (item.error ?? 'Failed')
                  : done
                      ? 'Saved to ${item.savedPath}'
                      : item.stage,
              key: const Key('downloadStatus'),
            ),
            if (!done && !failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: item.progress),
              ),
          ],
        ),
        trailing: done
            ? const Icon(Icons.play_circle_fill, color: Colors.greenAccent)
            : failed
                ? const Icon(Icons.error, color: Colors.redAccent)
                : null,
      ),
    );
  }
}
