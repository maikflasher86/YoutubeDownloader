import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import '../services/app_settings.dart';
import 'app_state.dart';

/// The embedded player needs a WebView, which exists on Android only here.
bool get inlinePlayerSupported => !kIsWeb && Platform.isAndroid;

/// Opens [info] in the inline player, or in the browser on desktop.
Future<void> openPreview(BuildContext context, VideoInfo info) async {
  if (inlinePlayerSupported) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => PreviewPage(info: info)));
  } else {
    await launchUrl(
      Uri.parse('https://www.youtube.com/watch?v=${info.id}'),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Plays a video with its title and buttons to queue a download.
class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.info});
  final VideoInfo info;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late final YoutubePlayerController _player =
      YoutubePlayerController.fromVideoId(
        videoId: widget.info.id,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );

  @override
  void dispose() {
    _player.close();
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
    return YoutubePlayerControllerProvider(
      controller: _player,
      child: Scaffold(
        appBar: AppBar(title: Text(info.title, maxLines: 1)),
        body: ListView(
          children: [
            YoutubePlayer(controller: _player),
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
      ),
    );
  }
}
