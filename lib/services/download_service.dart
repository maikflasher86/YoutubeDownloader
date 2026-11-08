import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/download_item.dart';
import 'platform_services.dart';
import 'youtube_source.dart';
import 'youtube_url.dart';

typedef ProgressCallback = void Function(double progress, String stage);

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadService {
  DownloadService({
    required this.source,
    required this.converter,
    required this.saver,
    required this.tempDir,
    this.stallTimeout = const Duration(seconds: 20),
  });

  final YoutubeSource source;
  final AudioConverter converter;
  final FileSaver saver;
  final Directory tempDir;

  /// Max time without receiving data before a stream counts as blocked.
  final Duration stallTimeout;

  Future<VideoInfo> fetchInfo(String input) async {
    final id = extractVideoId(input);
    if (id == null) throw DownloadException('No valid YouTube link found');
    return source.getInfo(id);
  }

  /// Downloads, converts if needed and saves. Returns the saved file.
  Future<SavedFile> download(
    VideoInfo info,
    DownloadKind kind, {
    int? height,
    ProgressCallback? onProgress,
  }) async {
    await tempDir.create(recursive: true);
    final base = sanitizeFileName(info.title);
    final isAudio = kind == DownloadKind.audio;

    final raw = await _fetchToFile(info, kind, base, height, onProgress);
    File result = raw;
    try {
      if (isAudio) {
        onProgress?.call(1, 'Converting to MP3');
        final mp3 = File('${tempDir.path}${Platform.pathSeparator}$base.mp3');
        await converter.toMp3(raw.path, mp3.path);
        result = mp3;
      }
      onProgress?.call(1, 'Saving');
      return await saver.save(result, audio: isAudio);
    } finally {
      for (final f in {raw, result}) {
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  Future<File> _fetchToFile(
    VideoInfo info,
    DownloadKind kind,
    String base,
    int? height,
    ProgressCallback? onProgress,
  ) async {
    Object? lastError;
    final sep = Platform.pathSeparator;
    await for (final candidate
        in source.candidates(info.id, kind, height: height)) {
      if (candidate.videoOnly) {
        try {
          return await _fetchMerged(info, candidate, base, onProgress);
        } catch (e) {
          debugPrint('merged ${candidate.height}p failed: $e');
          lastError = e;
          continue;
        }
      }
      final file = File(
          '${tempDir.path}$sep$base${kind == DownloadKind.audio ? '.raw' : ''}.${candidate.container}');
      try {
        await _writeStream(candidate, file, onProgress);
        return file;
      } catch (e) {
        debugPrint('stream ${candidate.container} failed: $e');
        lastError = e;
        if (file.existsSync()) file.deleteSync();
      }
    }
    throw DownloadException(lastError == null
        ? 'YouTube offered no downloadable stream'
        : 'Download blocked by YouTube: $lastError');
  }

  /// Downloads a video-only stream plus an audio track and merges both.
  Future<File> _fetchMerged(
    VideoInfo info,
    MediaStream video,
    String base,
    ProgressCallback? onProgress,
  ) async {
    final sep = Platform.pathSeparator;
    final videoFile =
        File('${tempDir.path}$sep$base.video.${video.container}');
    final audioFile = File('${tempDir.path}$sep$base.audio.m4a');
    final out = File('${tempDir.path}$sep$base.${video.container}');
    try {
      final label = video.height == null ? 'video' : '${video.height}p video';
      await _writeStream(
          video, videoFile, (p, _) => onProgress?.call(p * 0.8, 'Downloading $label'));
      var audioOk = false;
      Object? audioError;
      await for (final a in source.candidates(info.id, DownloadKind.audio)) {
        try {
          await _writeStream(a, audioFile,
              (p, _) => onProgress?.call(0.8 + p * 0.2, 'Downloading audio'));
          audioOk = true;
          break;
        } catch (e) {
          audioError = e;
          if (audioFile.existsSync()) audioFile.deleteSync();
        }
      }
      if (!audioOk) {
        throw DownloadException('No audio track available: $audioError');
      }
      onProgress?.call(1, 'Merging video and audio');
      await converter.mux(videoFile.path, audioFile.path, out.path);
      return out;
    } catch (_) {
      if (out.existsSync()) out.deleteSync();
      rethrow;
    } finally {
      for (final f in [videoFile, audioFile]) {
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  Future<void> _writeStream(
    MediaStream stream,
    File file,
    ProgressCallback? onProgress,
  ) async {
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in stream.open().timeout(stallTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (stream.totalBytes > 0) {
          onProgress?.call(
              (received / stream.totalBytes).clamp(0.0, 1.0), 'Downloading');
        }
      }
    } finally {
      await sink.close();
    }
    if (received == 0) throw DownloadException('Empty stream');
  }
}
