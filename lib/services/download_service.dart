import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/download_item.dart';
import 'youtube_source.dart';
import 'youtube_url.dart';

typedef ProgressCallback = void Function(double progress, DownloadStage stage);

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Converts an audio file (m4a/webm) to mp3 and merges video with audio.
abstract class AudioConverter {
  Future<void> toMp3(String input, String output);

  /// Combines the video track of [video] with the audio track of [audio]
  /// without re-encoding.
  Future<void> mux(String video, String audio, String output);
}

/// Shared ffmpeg commands. Subclasses only decide how ffmpeg is executed.
abstract class FfmpegConverter implements AudioConverter {
  /// Runs ffmpeg with [args] and returns the exit code and the log output.
  Future<(int?, String)> execute(List<String> args);

  @override
  Future<void> toMp3(String input, String output) => _run(
    ['-i', input, '-vn', '-codec:a', 'libmp3lame', '-q:a', '2', output],
    output,
    'MP3 conversion',
  );

  @override
  Future<void> mux(String video, String audio, String output) => _run(
    [
      '-i', video, '-i', audio, '-map', '0:v:0', '-map', '1:a:0', //
      '-c', 'copy', output,
    ],
    output,
    'Merging video and audio',
  );

  Future<void> _run(List<String> args, String output, String what) async {
    final (code, log) = await execute(['-y', ...args]);
    if (code != 0 || !File(output).existsSync()) {
      final tail = log.split('\n').where((l) => l.trim().isNotEmpty);
      throw Exception(
        '$what failed (code $code): ${tail.isEmpty ? '' : tail.last}',
      );
    }
  }
}

/// A file that was saved to public storage.
class SavedFile {
  const SavedFile({required this.location, this.uri, required this.mime});

  /// Human readable location, e.g. "Music/YouTube Downloader/a.mp3".
  final String location;

  /// URI used to open the file with the default player.
  final Uri? uri;
  final String mime;
}

/// Moves a finished file into the public storage (Music / Movies).
abstract class FileSaver {
  Future<SavedFile> save(File file, {required bool audio});
}

String mimeFor(String name) => switch (p.extension(name).toLowerCase()) {
  '.mp3' => 'audio/mpeg',
  '.webm' => 'video/webm',
  _ => 'video/mp4',
};

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

  Future<List<VideoInfo>> search(String query) => source.search(query);

  /// Downloads, converts if needed and saves. Returns the saved file.
  Future<SavedFile> download(
    VideoInfo info,
    DownloadKind kind, {
    int? height,
    ProgressCallback? onProgress,
  }) async {
    await tempDir.create(recursive: true);
    // Own folder per download, so parallel downloads never share file names.
    final work = await tempDir.createTemp('dl_');
    final base = sanitizeFileName(info.title);
    final isAudio = kind == DownloadKind.audio;

    try {
      var result = await _fetchToFile(
        work,
        info,
        kind,
        base,
        height,
        onProgress,
      );
      if (isAudio) {
        onProgress?.call(1, DownloadStage.converting);
        final mp3 = File(p.join(work.path, '$base.mp3'));
        await converter.toMp3(result.path, mp3.path);
        result = mp3;
      }
      onProgress?.call(1, DownloadStage.saving);
      return await saver.save(result, audio: isAudio);
    } finally {
      if (work.existsSync()) work.deleteSync(recursive: true);
    }
  }

  Future<File> _fetchToFile(
    Directory dir,
    VideoInfo info,
    DownloadKind kind,
    String base,
    int? height,
    ProgressCallback? onProgress,
  ) async {
    Object? lastError;
    await for (final candidate in source.candidates(
      info.id,
      kind,
      height: height,
    )) {
      if (candidate.videoOnly) {
        try {
          return await _fetchMerged(dir, info, candidate, base, onProgress);
        } catch (e) {
          debugPrint('merged ${candidate.height}p failed: $e');
          lastError = e;
          continue;
        }
      }
      final raw = kind == DownloadKind.audio ? '.raw' : '';
      final file = File(p.join(dir.path, '$base$raw.${candidate.container}'));
      try {
        await _writeStream(candidate, file, onProgress);
        return file;
      } catch (e) {
        debugPrint('stream ${candidate.container} failed: $e');
        lastError = e;
        if (file.existsSync()) file.deleteSync();
      }
    }
    throw DownloadException(
      lastError == null
          ? 'YouTube offered no downloadable stream'
          : 'Download blocked by YouTube: $lastError',
    );
  }

  /// Downloads a video-only stream plus an audio track and merges both.
  Future<File> _fetchMerged(
    Directory dir,
    VideoInfo info,
    MediaStream video,
    String base,
    ProgressCallback? onProgress,
  ) async {
    File temp(String name) => File(p.join(dir.path, name));
    final videoFile = temp('$base.video.${video.container}');
    final audioFile = temp('$base.audio.m4a');
    final out = temp('$base.mp4');
    try {
      await _writeStream(
        video,
        videoFile,
        (p, _) => onProgress?.call(p * 0.8, DownloadStage.downloadingVideo),
      );
      var audioOk = false;
      Object? audioError;
      await for (final a in source.candidates(info.id, DownloadKind.audio)) {
        try {
          await _writeStream(
            a,
            audioFile,
            (p, _) =>
                onProgress?.call(0.8 + p * 0.2, DownloadStage.downloadingAudio),
          );
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
      onProgress?.call(1, DownloadStage.merging);
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
            (received / stream.totalBytes).clamp(0.0, 1.0),
            DownloadStage.downloading,
          );
        }
      }
    } finally {
      await sink.close();
    }
    if (received == 0) throw DownloadException('Empty stream');
  }
}
