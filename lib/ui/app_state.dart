import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';
import '../services/download_service.dart';
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
    this.maxParallel = 3,
    this.persist = false,
  });

  /// Persists completed download IDs and unfinished queue items.
  final bool persist;
  static const _historyKey = 'downloadHistory';
  static const _downloadedItemsKey = 'downloadedItems';
  static const _downloadQueueKey = 'downloadQueue';
  final Map<String, Set<DownloadKind>> _downloadedItems = {};
  final Map<DownloadItem, bool> _fetchInfoByItem = {};
  Future<void> _historyWrite = Future<void>.value();

  void _markDownloaded(String videoId, DownloadKind kind) {
    _downloadedItems.putIfAbsent(videoId, () => {}).add(kind);
  }

  /// Restores completed IDs and resumes unfinished downloads.
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
        await prefs.remove(_historyKey);
      } catch (_) {
        await prefs.remove(_historyKey);
      }
    }

    final queue = prefs.getString(_downloadQueueKey);
    if (queue != null) {
      try {
        for (final entry in jsonDecode(queue) as List) {
          final record = entry as Map<String, dynamic>;
          final item = DownloadItem.fromJson(
            record['item'] as Map<String, dynamic>,
          );
          if (item.status == DownloadStatus.done ||
              _downloadedItems[item.info.id]?.contains(item.kind) == true) {
            continue;
          }
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

    await saveHistory();
    final newCount = _downloadedItems.values.fold<int>(
      0,
      (count, kinds) => count + kinds.length,
    );
    if (newCount != oldCount || downloads.isNotEmpty) notifyListeners();
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
    final downloadedItems = jsonEncode([
      for (final entry in _downloadedItems.entries)
        for (final kind in entry.value) {'id': entry.key, 'kind': kind.name},
    ]);
    final queue = jsonEncode([
      for (final item in downloads)
        if (item.status != DownloadStatus.done)
          {'item': item.toJson(), 'fetchInfo': _fetchInfoByItem[item] ?? false},
    ]);
    _historyWrite = _historyWrite.then<void>((_) async {
      await prefs.setString(_downloadedItemsKey, downloadedItems);
      await prefs.setString(_downloadQueueKey, queue);
      await prefs.remove(_historyKey);
    });
    await _historyWrite;
  }

  Future<void> _resumeQueuedDownloads() async {
    await Future.wait([
      for (final item in downloads)
        if (item.status == DownloadStatus.queued)
          _process(item, fetchInfo: _fetchInfoByItem[item] ?? false),
    ]);
  }

  /// Maximum number of downloads that run at the same time.
  final int maxParallel;
  int _active = 0;
  final _waiting = <Completer<void>>[];

  final DownloadService _service;
  final Future<void> Function(SavedFile) _opener;

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
        onProgress: (p, stage) {
          item.progress = p;
          item.stage = stage;
          notifyListeners();
        },
      );
      item.status = DownloadStatus.done;
      item.progress = 1;
      item.stage = DownloadStage.saved;
      _markDownloaded(item.info.id, item.kind);
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.error = e.toString();
    }
    notifyListeners();
    await saveHistory();
  }
}
