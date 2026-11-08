import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import '../models/video_quality.dart';
import '../services/app_settings.dart';
import '../services/youtube_url.dart';
import 'app_state.dart';
import 'theme.dart';

/// Lets the user paste many YouTube links and download them as MP3 or video.
class BatchPage extends StatefulWidget {
  const BatchPage({super.key});

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final _controller = TextEditingController();
  DownloadKind _kind = DownloadKind.audio;
  VideoQuality? _quality;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    final current = _controller.text;
    _controller.text = current.isEmpty ? text : '$current\n$text';
    setState(() {});
  }

  void _start() {
    final l = AppLocalizations.of(context);
    final quality = _quality ?? context.read<AppSettings>().videoQuality;
    final text = _controller.text;
    final count = extractVideoIds(text).length;
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.batchStarted(count))));
    state.startBatch(
      text,
      _kind,
      height: _kind == DownloadKind.video ? quality.height : null,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quality = _quality ?? context.watch<AppSettings>().videoQuality;
    final count = extractVideoIds(_controller.text).length;
    return Scaffold(
      appBar: AppBar(title: Text(l.batchDownload)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            key: const Key('batchField'),
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.batchHint,
              suffixIcon: IconButton(
                key: const Key('batchPasteButton'),
                icon: const Icon(Icons.content_paste),
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<DownloadKind>(
            key: const Key('batchKind'),
            segments: [
              ButtonSegment(
                value: DownloadKind.audio,
                icon: const Icon(Icons.music_note),
                label: Text(l.mp3),
              ),
              ButtonSegment(
                value: DownloadKind.video,
                icon: const Icon(Icons.movie),
                label: Text(l.video),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          if (_kind == DownloadKind.video) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.high_quality_outlined,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Text(l.videoQuality),
                  const Spacer(),
                  DropdownButton<VideoQuality>(
                    value: quality,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      for (final q in VideoQuality.values)
                        DropdownMenuItem(value: q, child: Text(q.label)),
                    ],
                    onChanged: (q) => setState(() => _quality = q),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('batchStartButton'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: surfaceHigh,
            ),
            onPressed: count == 0 ? null : _start,
            icon: const Icon(Icons.download),
            label: Text(count == 0 ? l.batchStart : '${l.batchStart} ($count)'),
          ),
        ],
      ),
    );
  }
}
