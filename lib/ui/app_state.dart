import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/delete_file.dart';
import '../services/youtube_url.dart';

/// A user-visible error. The UI translates [kind]; [details] is technical.
enum AppErrorKind { invalidLink, load, open }

class AppError {
  const AppError(this.kind, [this.details]);
  final AppErrorKind kind;
  final String? details;
}

class AppState extends ChangeNotifier {
  AppState(
    this._service, {
    required this._opener,
    this.deleter,
    this.maxParallel = 3,
    this.persist = false,
    this.silenceThresholdForDownload,
  });

  final int? Function()? silenceThresholdForDownload;

  /// Keeps completed download IDs across app restarts, not the visible queue.
  final bool persist;
  static const _historyKey = 'downloadHistory';
  static const _downloadedItemsKey = 'downloadedItems';
  static const _downloadQueueKey = 'downloadQueue';
  final Map<String, Set<DownloadKind>> _downloadedItems = {};
  final Map<String, Set<DownloadKind>> _olderMarkers = {};
  final Map<DownloadItem, bool> _fetchInfoByItem = {};
  final Set<Uri> _deleting = {};
  Completer<void>? _deletionDone;
  Future<void> _historyWrite = Future<void>.value();

  void _markDownloaded(String videoId, DownloadKind kind) {
    _downloadedItems.putIfAbsent(videoId, () => {}).add(kind);
  }

  /// Restores completed download IDs without restoring the visible queue.
  Future<void> loadHistory() async {
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    final oldCount = _downloadedItems.values.fold<int>(
      0,
      (count, kinds) => count + kinds.length,
    );
    final downloadedItems = prefs.getString(_downloadedItemsKey);
    if (downloadedItems != null) {
      try {
        for (final entry in jsonDecode(downloadedItems) as List) {
          final item = entry as Map<String, dynamic>;
          _markDownloaded(
            item['id'] as String,
            DownloadKind.values.byName(item['kind'] as String),
          );
        }
      } catch (_) {
        await prefs.remove(_downloadedItemsKey);
        _downloadedItems.clear();
      }
    }

    final oldHistory = prefs.getString(_historyKey);
    if (oldHistory != null) {
      try {
        final items = [
          for (final j in jsonDecode(oldHistory) as List)
            DownloadItem.fromJson(j),
        ];
        for (final item in items) {
          if (item.status == DownloadStatus.done) {
            _markDownloaded(item.info.id, item.kind);
          }
        }
        await _saveDownloadedItems(prefs);
        await prefs.remove(_historyKey);
      } catch (_) {
        await prefs.remove(_historyKey);
      }
    }

    final newCount = _downloadedItems.values.fold<int>(
      0,
      (count, kinds) => count + kinds.length,
    );
    for (final entry in _downloadedItems.entries) {
      _olderMarkers[entry.key] = Set.of(entry.value);
    }

    final queue = prefs.getString(_downloadQueueKey);
    if (queue != null) {
      try {
        for (final entry in jsonDecode(queue) as List) {
          final record = entry as Map<String, dynamic>;
          final item = DownloadItem.fromJson(
            record['item'] as Map<String, dynamic>,
          );
          if (item.status == DownloadStatus.done) continue;
          if (item.status == DownloadStatus.running) {
            item.status = DownloadStatus.queued;
            item.progress = 0;
            item.stage = DownloadStage.queued;
          }
          downloads.add(item);
          _fetchInfoByItem[item] = record['fetchInfo'] as bool? ?? false;
        }
      } catch (_) {
        downloads.clear();
        _fetchInfoByItem.clear();
        await prefs.remove(_downloadQueueKey);
      }
    }

    if (newCount != oldCount || downloads.isNotEmpty) notifyListeners();
    await saveHistory();
    unawaited(_resumeQueuedDownloads());
  }

  Future<void> saveHistory() async {
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    for (final download in downloads) {
      if (download.status == DownloadStatus.done) {
        _markDownloaded(download.info.id, download.kind);
      }
    }
    await _saveDownloadedItems(prefs);
    await _saveDownloadQueue(prefs);
    await prefs.remove(_historyKey);
  }

  Future<void> _saveDownloadQueue(SharedPreferences prefs) async {
    final queue = jsonEncode([
      for (final item in downloads)
        if (item.status != DownloadStatus.done)
          {'item': item.toJson(), 'fetchInfo': _fetchInfoByItem[item] ?? false},
    ]);
    Future<void> write() async {
      final saved = await prefs.setString(_downloadQueueKey, queue);
      if (!saved) throw StateError('Could not save download queue');
    }

    _historyWrite = _historyWrite.then<void>(
      (_) => write(),
      onError: (_) => write(),
    );
    await _historyWrite;
  }

  Future<void> _resumeQueuedDownloads() async {
    await Future.wait([
      for (final item in downloads)
        if (item.status == DownloadStatus.queued)
          _process(item, fetchInfo: _fetchInfoByItem[item] ?? false),
    ]);
  }

  Future<void> _saveDownloadedItems(SharedPreferences prefs) async {
    Future<void> write() async {
      final saved = await prefs.setString(
        _downloadedItemsKey,
        jsonEncode([
          for (final entry in _downloadedItems.entries)
            for (final kind in entry.value)
              {'id': entry.key, 'kind': kind.name},
        ]),
      );
      if (!saved) throw StateError('Could not save download markers');
    }

    _historyWrite = _historyWrite.then<void>(
      (_) => write(),
      onError: (_) => write(),
    );
    await _historyWrite;
  }

  /// Maximum number of downloads that run at the same time.
  final int maxParallel;
  int _active = 0;
  final _waiting = <Completer<void>>[];

  final DownloadService _service;
  final Future<void> Function(SavedFile) _opener;
  final Future<void> Function(SavedFile)? deleter;

  bool isDeleting(DownloadItem item) => _deleting.contains(item.saved?.uri);

  bool get hasPendingDownloads => downloads.any(
    (d) =>
        d.status == DownloadStatus.running || d.status == DownloadStatus.queued,
  );

  bool get deletionInProgress => _deleting.isNotEmpty;

  Future<String> fileIdentity(Uri uri) async {
    if (uri.scheme != 'file') return uri.toString();
    final file = File.fromUri(uri);
    String path;
    try {
      path = await file.resolveSymbolicLinks();
    } on FileSystemException catch (error) {
      final code = error.osError?.errorCode;
      if (code != 2 && !(Platform.isWindows && code == 3)) rethrow;
      path = p.absolute(file.path);
    }
    path = p.normalize(path);
    return Platform.isWindows ? path.toLowerCase() : path;
  }

  Future<Set<String>> currentFileIdentities() async {
    final uris = downloads
        .where((d) => d.status == DownloadStatus.done && d.saved?.uri != null)
        .map((d) => d.saved!.uri!)
        .toSet();
    return (await Future.wait(uris.map(fileIdentity))).toSet();
  }

  Future<void> deleteOlder(
    SavedFile saved,
    Future<void> Function() deleteFile,
  ) async {
    final uri = saved.uri;
    if (uri == null) throw const DeleteFailure(DeleteFailureKind.unavailable);
    if (_deleting.isNotEmpty || hasPendingDownloads) {
      throw const DeleteFailure(DeleteFailureKind.busy);
    }
    _deleting.add(uri);
    _deletionDone = Completer<void>();
    notifyListeners();
    try {
      final identity = await fileIdentity(uri);
      if ((await currentFileIdentities()).contains(identity)) {
        throw const DeleteFailure(DeleteFailureKind.unavailable);
      }
      await deleteFile();
    } finally {
      _deleting.remove(uri);
      _deletionDone!.complete();
      _deletionDone = null;
      notifyListeners();
    }
  }

  Future<void> openSaved(SavedFile saved) => _opener(saved);

  Future<void> delete(DownloadItem item) async {
    final saved = item.saved;
    final uri = saved?.uri;
    if (!downloads.contains(item) ||
        item.status != DownloadStatus.done ||
        saved == null ||
        uri == null ||
        deleter == null) {
      throw const DeleteFailure(DeleteFailureKind.unavailable);
    }
    if (_deleting.isNotEmpty || hasPendingDownloads) {
      throw const DeleteFailure(DeleteFailureKind.busy);
    }
    _deleting.add(uri);
    _deletionDone = Completer<void>();
    notifyListeners();
    try {
      await deleter!(saved);
      final removed = downloads
          .where((d) => d.status == DownloadStatus.done && d.saved?.uri == uri)
          .toList();
      final previous = {
        for (final entry in _downloadedItems.entries)
          entry.key: Set<DownloadKind>.of(entry.value),
      };
      for (final d in removed) {
        final stillPresent = downloads.any(
          (other) =>
              other.status == DownloadStatus.done &&
              !removed.contains(other) &&
              other.info.id == d.info.id &&
              other.kind == d.kind,
        );
        if (!stillPresent &&
            _olderMarkers[d.info.id]?.contains(d.kind) != true) {
          _downloadedItems[d.info.id]?.remove(d.kind);
          if (_downloadedItems[d.info.id]?.isEmpty == true) {
            _downloadedItems.remove(d.info.id);
          }
        }
      }
      try {
        if (persist) {
          final prefs = await SharedPreferences.getInstance();
          await _saveDownloadedItems(prefs);
        }
      } catch (e) {
        _downloadedItems
          ..clear()
          ..addAll(previous);
        throw DeleteFailure(DeleteFailureKind.persistence, '$e');
      }
      downloads.removeWhere(removed.contains);
    } finally {
      _deleting.remove(uri);
      _deletionDone!.complete();
      _deletionDone = null;
      notifyListeners();
    }
  }

  /// Opens a finished download with the default player; reports failures.
  Future<void> open(DownloadItem item) async {
    final saved = item.saved;
    if (saved == null) return;
    try {
      await _opener(saved);
    } catch (e) {
      error = AppError(AppErrorKind.open, '$e');
      notifyListeners();
    }
  }

  VideoInfo? video;
  bool loading = false;
  AppError? error;
  final List<DownloadItem> downloads = [];

  /// Called with a URL or any text containing one (also from the share sheet).
  Future<void> loadLink(String? text) async {
    if (extractVideoId(text) == null) {
      error = const AppError(AppErrorKind.invalidLink);
      video = null;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    video = null;
    notifyListeners();
    try {
      video = await _service.fetchInfo(text!);
    } catch (e) {
      error = AppError(AppErrorKind.load, '$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Adds an already known video (for example a search result) to the queue.
  Future<void> enqueue(VideoInfo info, DownloadKind kind, {int? height}) async {
    final item = DownloadItem(info: info, kind: kind, height: height);
    downloads.insert(0, item);
    _fetchInfoByItem[item] = false;
    notifyListeners();
    await _process(item, fetchInfo: false);
  }

  /// True when [videoId] is already queued, running or done as [kind].
  bool isAdded(String videoId, DownloadKind kind) =>
      _downloadedItems[videoId]?.contains(kind) == true ||
      downloads.any(
        (d) =>
            d.info.id == videoId &&
            d.kind == kind &&
            d.status != DownloadStatus.failed,
      );

  Future<List<VideoInfo>> search(String query) => _service.search(query);

  Future<String> previewUrl(String videoId) => _service.previewUrl(videoId);

  Future<void> startDownload(DownloadKind kind, {int? height}) async {
    final info = video;
    if (info == null) return;
    final item = DownloadItem(info: info, kind: kind, height: height);
    downloads.insert(0, item);
    _fetchInfoByItem[item] = false;
    notifyListeners();
    await _process(item, fetchInfo: false);
  }

  /// Queues every YouTube link in [text]. Up to [maxParallel] downloads run
  /// at once; the others wait and stay visible as queued. Failures stay in
  /// the list.
  Future<int> startBatch(String text, DownloadKind kind, {int? height}) async {
    final ids = extractVideoIds(text);
    final items = [
      for (final id in ids)
        DownloadItem(
          info: VideoInfo(
            id: id,
            title: 'https://www.youtube.com/watch?v=$id',
            author: '',
            thumbnailUrl: '',
          ),
          kind: kind,
          height: height,
          status: DownloadStatus.queued,
          stage: DownloadStage.queued,
        ),
    ];
    downloads.insertAll(0, items);
    for (final item in items) {
      _fetchInfoByItem[item] = true;
    }
    notifyListeners();
    await Future.wait([for (final i in items) _process(i, fetchInfo: true)]);
    return ids.length;
  }

  /// Waits for a free slot, then downloads [item].
  Future<void> _process(DownloadItem item, {required bool fetchInfo}) async {
    final deletion = _deletionDone;
    if (deletion != null) {
      item.status = DownloadStatus.queued;
      item.stage = DownloadStage.queued;
      notifyListeners();
      await saveHistory();
      await deletion.future;
    }
    if (_active >= maxParallel) {
      item.status = DownloadStatus.queued;
      item.stage = DownloadStage.queued;
      notifyListeners();
      await saveHistory();
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    } else {
      _active++;
    }
    try {
      item.status = DownloadStatus.running;
      item.stage = DownloadStage.starting;
      notifyListeners();
      await saveHistory();
      if (fetchInfo) {
        try {
          item.info = await _service.fetchInfo(item.info.title);
          _fetchInfoByItem[item] = false;
          await saveHistory();
        } catch (e) {
          item.status = DownloadStatus.failed;
          item.error = e.toString();
          notifyListeners();
          await saveHistory();
          return;
        }
      }
      await _run(item);
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  Future<void> _run(DownloadItem item) async {
    final info = item.info, kind = item.kind, height = item.height;
    try {
      item.saved = await _service.download(
        info,
        kind,
        height: height,
        silenceThresholdDb: kind == DownloadKind.audio
            ? silenceThresholdForDownload?.call()
            : null,
        onProgress: (p, stage) {
          item.progress = p;
          item.stage = stage;
          notifyListeners();
        },
      );
      item.status = DownloadStatus.done;
      item.progress = 1;
      item.stage = DownloadStage.saved;
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.error = e.toString();
    }
    notifyListeners();
    await saveHistory();
  }
}
