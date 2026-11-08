import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import '../services/app_settings.dart';
import 'app_state.dart';

/// Opens [info] in the in-app player.
Future<void> openPreview(BuildContext context, VideoInfo info) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => PreviewPage(info: info)));

/// Plays a video with its title and buttons to queue a download.
class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.info});
  final VideoInfo info;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final _player = Player();
  late final VideoController _video = VideoController(_player);
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await context.read<AppState>().previewUrl(widget.info.id);
      if (mounted) await _player.open(Media(url));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _add(DownloadKind kind) {
    final quality = context.read<AppSettings>().videoQuality;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).addedToQueue),
        duration: const Duration(seconds: 1),
      ),
    );
    context.read<AppState>().enqueue(
      widget.info,
      kind,
      height: kind == DownloadKind.video ? quality.height : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = widget.info;
    return Scaffold(
      appBar: AppBar(title: Text(info.title, maxLines: 1)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _error != null
                ? Center(child: Text('$_error'))
                : Video(controller: _video),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  info.author,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('previewMp3'),
                        onPressed: () => _add(DownloadKind.audio),
                        icon: const Icon(Icons.music_note),
                        label: Text(l.mp3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('previewVideo'),
                        onPressed: () => _add(DownloadKind.video),
                        icon: const Icon(Icons.movie),
                        label: Text(l.video),
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
}
