import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import '../models/video_quality.dart';
import '../services/app_settings.dart';
import '../services/delete_file.dart';
import '../services/youtube_url.dart';
import 'app_state.dart';
import 'batch_page.dart';
import 'l10n_text.dart';
import 'older_files_view.dart';
import 'settings_page.dart';
import 'theme.dart';

class LinkPage extends StatefulWidget {
  const LinkPage({super.key, this.initialLink, this.embedded = false});

  final String? initialLink;
  final bool embedded;

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  final _controller = TextEditingController();
  DownloadKind _kind = DownloadKind.video;
  VideoQuality? _quality;

  @override
  void initState() {
    super.initState();
    final link = widget.initialLink;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLink(link);
      });
    }
  }

  void _openLink(String text) {
    setState(() => _controller.text = text);
    context.read<AppState>().loadLink(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) _openLink(data!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l = AppLocalizations.of(context);
    final quality = _quality ?? context.watch<AppSettings>().videoQuality;
    final currentVideo = state.video;
    final matchesLink =
        currentVideo != null &&
        currentVideo.id == extractVideoId(_controller.text);
    final content = LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth >= 800 ? 36 : 16,
          24,
          constraints.maxWidth >= 800 ? 36 : 16,
          32,
        ),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.downloads,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.linkTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('urlField'),
                            controller: _controller,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (v) =>
                                context.read<AppState>().loadLink(v),
                            decoration: InputDecoration(
                              hintText: l.pasteHint,
                              prefixIcon: const Icon(Icons.link),
                              suffixIcon: IconButton(
                                key: const Key('pasteButton'),
                                tooltip: l.linkTitle,
                                icon: const Icon(Icons.content_paste),
                                onPressed: _paste,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SegmentedButton<DownloadKind>(
                                key: const Key('formatSelector'),
                                segments: [
                                  ButtonSegment(
                                    value: DownloadKind.video,
                                    label: Text(l.video),
                                  ),
                                  ButtonSegment(
                                    value: DownloadKind.audio,
                                    label: Text(l.mp3),
                                  ),
                                ],
                                selected: {_kind},
                                onSelectionChanged: (value) =>
                                    setState(() => _kind = value.first),
                              ),
                              if (_kind == DownloadKind.video)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(l.videoQuality),
                                    const SizedBox(width: 8),
                                    DropdownButton<VideoQuality>(
                                      key: const Key('qualityDropdown'),
                                      value: quality,
                                      items: [
                                        for (final q in VideoQuality.values)
                                          DropdownMenuItem(
                                            value: q,
                                            child: Text(q.label),
                                          ),
                                      ],
                                      onChanged: (q) =>
                                          setState(() => _quality = q),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (state.loading)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  state.error!.text(l),
                                  key: const Key('errorText'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (matchesLink) ...[
                              _VideoSummary(info: currentVideo),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                key: const Key('downloadButton'),
                                onPressed: () => state.startDownload(
                                  _kind,
                                  height: _kind == DownloadKind.video
                                      ? quality.height
                                      : null,
                                ),
                                icon: const Icon(Icons.download),
                                label: Text(l.batchStart),
                              ),
                            ] else
                              FilledButton.icon(
                                key: const Key('loadButton'),
                                onPressed:
                                    extractVideoId(_controller.text) == null
                                    ? null
                                    : () => state.loadLink(_controller.text),
                                icon: const Icon(Icons.search),
                                label: Text(l.loadVideo),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l.downloads,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  for (final d in state.downloads) DownloadTile(item: d),
                  if (context.watch<AppSettings>().showOlderFiles)
                    const OlderFilesView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.linkTitle),
        actions: [
          IconButton(
            key: const Key('batchButton'),
            tooltip: l.batchDownload,
            icon: const Icon(Icons.playlist_add),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BatchPage())),
          ),
          IconButton(
            key: const Key('settingsButton'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: content,
    );
  }
}

class _VideoSummary extends StatelessWidget {
  const _VideoSummary({required this.info});
  final VideoInfo info;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 96,
          height: 54,
          child: Image.network(
            info.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: surfaceHigh,
              child: Icon(Icons.play_circle_outline),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.title,
              key: const Key('videoTitle'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              info.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    ],
  );
}

class DownloadTile extends StatelessWidget {
  const DownloadTile({super.key, required this.item});
  final DownloadItem item;

  Future<void> _delete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(
          l.deleteConfirmBody(item.saved?.location ?? item.info.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.delete(item);
    } catch (error) {
      if (!context.mounted) return;
      final message = switch (error) {
        DeleteFailure(kind: DeleteFailureKind.missing) => l.deleteMissing,
        DeleteFailure(kind: DeleteFailureKind.missingOrDenied) =>
          l.deleteMissingOrDenied,
        DeleteFailure(kind: DeleteFailureKind.unavailable) =>
          l.deleteUnavailable,
        DeleteFailure(kind: DeleteFailureKind.busy) => l.deleteBusy,
        DeleteFailure(
          kind: DeleteFailureKind.persistence,
          details: final details,
        ) =>
          l.deletePersistenceFailed(details ?? ''),
        _ => l.deleteFailed('$error'),
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final done = item.status == DownloadStatus.done;
    final failed = item.status == DownloadStatus.failed;
    final tint = failed
        ? Colors.redAccent
        : (done ? const Color(0xFF7AC8A2) : accent);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const Key('downloadTile'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: done ? () => context.read<AppState>().open(item) : null,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: 64,
            height: 48,
            child: Image.network(
              item.info.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: surfaceHigh,
                child: Icon(
                  item.kind == DownloadKind.audio
                      ? Icons.music_note
                      : Icons.movie,
                  color: tint,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          item.info.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failed ? (item.error ?? l.failed) : item.stage.text(l),
              key: const Key('downloadStatus'),
            ),
            if (item.status == DownloadStatus.running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 3,
                ),
              ),
          ],
        ),
        trailing: done
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill, color: tint),
                  IconButton(
                    key: const Key('deleteDownload'),
                    tooltip: l.deleteFile,
                    onPressed: context.watch<AppState>().isDeleting(item)
                        ? null
                        : () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              )
            : failed
            ? Icon(Icons.error, color: tint)
            : item.status == DownloadStatus.queued
            ? const Icon(Icons.schedule, color: mutedColor)
            : null,
      ),
    );
  }
}
