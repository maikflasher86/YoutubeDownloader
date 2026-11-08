import 'dart:async';

import 'package:flutter/foundation.dart';

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
  AppState(this._service, {required this._opener, this.maxParallel = 3});

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
    notifyListeners();
    await _process(item, fetchInfo: false);
  }

  Future<List<VideoInfo>> search(String query) => _service.search(query);

  Future<void> startDownload(DownloadKind kind, {int? height}) async {
    final info = video;
    if (info == null) return;
    final item = DownloadItem(info: info, kind: kind, height: height);
    downloads.insert(0, item);
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
      if (fetchInfo) {
        try {
          item.info = await _service.fetchInfo(item.info.title);
        } catch (e) {
          item.status = DownloadStatus.failed;
          item.error = e.toString();
          notifyListeners();
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
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.error = e.toString();
    }
    notifyListeners();
  }
}
