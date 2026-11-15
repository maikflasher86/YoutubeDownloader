import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/older_files.dart';
import 'app_state.dart';

enum _FileFilter { all, audio, video }

class OlderFilesView extends StatefulWidget {
  const OlderFilesView({super.key});

  @override
  State<OlderFilesView> createState() => _OlderFilesViewState();
}

class _OlderFilesViewState extends State<OlderFilesView> {
  List<OlderFile> _files = [];
  Object? _error;
  List<String> _issues = [];
  bool _loading = false;
  bool _refreshAgain = false;
  bool _deleting = false;
  bool _initialized = false;
  String? _folder;
  String _currentSignature = '';
  String _search = '';
  _FileFilter _filter = _FileFilter.all;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<AppSettings>();
    final state = context.watch<AppState>();
    final signature = state.downloads
        .where((d) => d.saved?.uri != null)
        .map((d) => '${d.status}:${d.saved!.uri}')
        .join('|');
    if (!_initialized ||
        _folder != settings.folderUri ||
        _currentSignature != signature) {
      _initialized = true;
      _folder = settings.folderUri;
      _currentSignature = signature;
      _revision++;
      _files = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    if (_loading) {
      _refreshAgain = true;
      return;
    }
    final repository = context.read<OlderFilesRepository>();
    final state = context.read<AppState>();
    do {
      _refreshAgain = false;
      final revision = ++_revision;
      setState(() {
        _loading = true;
        _error = null;
        _issues = [];
        _files = [];
      });
      try {
        final scan = await repository.list();
        final current = await state.currentFileIdentities();
        final unique = <String, OlderFile>{};
        for (final file in scan.files) {
          final uri = file.saved.uri;
          if (uri == null) throw StateError('File has no URI');
          final identity = await state.fileIdentity(uri);
          if (!current.contains(identity)) unique[identity] = file;
        }
        final result = unique.values.toList()
          ..sort(
            (a, b) => (b.modified ?? DateTime(1970)).compareTo(
              a.modified ?? DateTime(1970),
            ),
          );
        if (mounted && revision == _revision && !_refreshAgain) {
          setState(() {
            _files = result;
            _issues = scan.issues;
          });
        }
      } catch (error) {
        if (mounted && revision == _revision && !_refreshAgain) {
          setState(() => _error = error);
        }
      }
    } while (mounted && _refreshAgain);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(OlderFile file) async {
    final l = AppLocalizations.of(context);
    try {
      await context.read<AppState>().openSaved(file.saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorOpen('$error'))));
      }
    }
  }

  Future<void> _delete(OlderFile file) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final repository = context.read<OlderFilesRepository>();
    final revision = _revision;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody(file.saved.location)),
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
    if (confirmed != true || !mounted) return;
    if (revision != _revision || !_files.contains(file) || _loading) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.deleteUnavailable)));
      return;
    }
    setState(() => _deleting = true);
    try {
      await state.deleteOlder(file.saved, () => repository.delete(file));
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.deleteFailed('$error'))));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final files = _files.where((file) {
      final matchType =
          _filter == _FileFilter.all ||
          (_filter == _FileFilter.audio && file.audio) ||
          (_filter == _FileFilter.video && !file.audio);
      return matchType &&
          file.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l.olderFiles),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        Text(l.olderFilesDescription),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('searchOlderFiles'),
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  labelText: l.searchFiles,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            IconButton(
              key: const Key('refreshOlderFiles'),
              tooltip: l.refreshFiles,
              onPressed: _loading || _deleting ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (filter, label) in [
              (_FileFilter.all, l.allFiles),
              (_FileFilter.video, l.video),
              (_FileFilter.audio, l.audio),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        if (!_loading && _issues.isNotEmpty)
          Text(
            l.olderFilesError(_issues.join('\n')),
            key: const Key('olderFilesWarning'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(
            l.olderFilesError('$_error'),
            key: const Key('olderFilesError'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (files.isEmpty && _issues.isEmpty)
          Text(_files.isEmpty ? l.olderFilesEmpty : l.olderFilesNoMatch)
        else
          for (final file in files)
            Card(
              child: ListTile(
                key: ValueKey('older:${file.saved.uri}'),
                leading: Icon(file.audio ? Icons.music_note : Icons.movie),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    file.audio ? l.audio : l.video,
                    if (file.size != null)
                      '${(file.size! / 1048576).toStringAsFixed(1)} MB',
                    if (file.modified != null)
                      MaterialLocalizations.of(context)
                          .formatShortDate(file.modified!),
                    file.saved.location,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(file),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l.openFile,
                      onPressed: () => _open(file),
                      icon: const Icon(Icons.open_in_new),
                    ),
                    IconButton(
                      tooltip: l.deleteFile,
                      onPressed:
                          _deleting ||
                              state.deletionInProgress ||
                              state.hasPendingDownloads
                          ? null
                          : () => _delete(file),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
