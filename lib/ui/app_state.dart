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
  AppState(this._service, {required this._opener});

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

  Future<void> startDownload(DownloadKind kind, {int? height}) async {
    final info = video;
    if (info == null) return;
    final item = DownloadItem(info: info, kind: kind, height: height);
    downloads.insert(0, item);
    notifyListeners();
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
