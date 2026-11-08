import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/download_item.dart';
import '../models/video_quality.dart';
import '../services/app_settings.dart';
import 'app_state.dart';
import 'settings_page.dart';
import 'theme.dart';

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
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
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
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: surfaceHigh,
            ),
            onPressed: state.loading
                ? null
                : () => context.read<AppState>().loadLink(_controller.text),
            icon: const Icon(Icons.search),
            label: const Text('Load video'),
          ),
          const SizedBox(height: 20),
          if (state.loading)
            const Center(child: CircularProgressIndicator())
          else if (state.error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(state.error!,
                  key: const Key('errorText'),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (state.video != null) _VideoCard(info: state.video!),
          if (state.downloads.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Downloads',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
  VideoQuality? _choice;

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  info.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Colors.black26,
                    child: Icon(Icons.play_circle_outline, size: 48),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA000000)],
                    ),
                  ),
                ),
                if (info.duration != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_fmt(info.duration!),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title,
                    key: const Key('videoTitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [info.author, if (info.duration != null) _fmt(info.duration!)]
                      .join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.high_quality_outlined,
                          size: 20, color: Colors.white70),
                      const SizedBox(width: 10),
                      const Text('Video quality'),
                      const Spacer(),
                      DropdownButton<VideoQuality>(
                        key: const Key('qualityDropdown'),
                        value: quality,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(16),
                        items: [
                          for (final q in VideoQuality.values)
                            DropdownMenuItem(value: q, child: Text(q.label)),
                        ],
                        onChanged: (q) => setState(() => _choice = q),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                            height: quality.height),
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
    final tint =
        failed ? Colors.redAccent : (done ? Colors.white70 : accent);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const Key('downloadTile'),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: done ? () => context.read<AppState>().open(item) : null,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
              item.kind == DownloadKind.audio ? Icons.music_note : Icons.movie,
              color: tint),
        ),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                      value: item.progress, minHeight: 6),
                ),
              ),
          ],
        ),
        trailing: done
            ? const Icon(Icons.play_circle_fill, color: Colors.white70)
            : failed
                ? const Icon(Icons.error, color: Colors.redAccent)
                : null,
      ),
    );
  }
}
