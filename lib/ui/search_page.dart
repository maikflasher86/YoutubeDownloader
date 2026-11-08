import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import '../services/app_settings.dart';
import 'app_state.dart';
import 'preview_page.dart';

/// Searches YouTube and adds results to the download queue.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<VideoInfo>? _results;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<AppState>().search(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(VideoInfo info, DownloadKind kind) {
    final quality = context.read<AppSettings>().videoQuality;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).addedToQueue),
        duration: const Duration(seconds: 1),
      ),
    );
    context.read<AppState>().enqueue(
      info,
      kind,
      height: kind == DownloadKind.video ? quality.height : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(l.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('searchField'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: l.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  key: const Key('searchButton'),
                  tooltip: l.search,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.errorSearch(_error!),
                key: const Key('searchError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (results != null && results.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.searchEmpty),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: results?.length ?? 0,
              itemBuilder: (context, i) {
                final v = results![i];
                return ListTile(
                  key: Key('searchResult$i'),
                  onTap: () => openPreview(context, v),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 96,
                      height: 54,
                      child: Image.network(
                        v.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black26,
                          child: Icon(Icons.play_circle_outline),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      v.author,
                      if (v.duration != null) _fmt(v.duration!),
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('searchMp3$i'),
                        tooltip: l.mp3,
                        icon: const Icon(Icons.music_note),
                        onPressed: () => _add(v, DownloadKind.audio),
                      ),
                      IconButton(
                        key: Key('searchVideo$i'),
                        tooltip: l.video,
                        icon: const Icon(Icons.movie),
                        onPressed: () => _add(v, DownloadKind.video),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$s';
  }
}
