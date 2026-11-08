import 'dart:async';

import 'dart:io' show HttpException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/download_item.dart';

/// A downloadable media stream. [open] may be called once per instance.
class MediaStream {
  MediaStream({
    required this.container,
    required this.totalBytes,
    required this.open,
    this.videoOnly = false,
    this.height,
  });

  /// File extension without dot, e.g. "mp4", "webm".
  final String container;
  final int totalBytes;
  final Stream<List<int>> Function() open;

  /// True when the stream has no audio track and must be merged with audio.
  final bool videoOnly;

  /// Video height in pixels, when known.
  final int? height;
}

/// Thin abstraction over the YouTube backend so the download logic is testable.
abstract class YoutubeSource {
  Future<VideoInfo> getInfo(String videoId);

  /// Returns candidate streams, best first. Each candidate may come from a
  /// different YouTube client, because YouTube blocks individual clients often.
  /// For video, [height] is the wanted maximum resolution.
  Stream<MediaStream> candidates(
    String videoId,
    DownloadKind kind, {
    int? height,
  });

  void close();
}

class ExplodeYoutubeSource implements YoutubeSource {
  ExplodeYoutubeSource({YoutubeExplode? client})
    : _yt = client ?? YoutubeExplode();

  final YoutubeExplode _yt;

  // Order matters: the first client that yields a working stream wins.
  static final _clients = <YoutubeApiClient>[
    YoutubeApiClient.androidSdkless,
    YoutubeApiClient.androidVr,
    YoutubeApiClient.tv,
    YoutubeApiClient.mweb,
  ];

  @override
  Future<VideoInfo> getInfo(String videoId) async {
    final v = await _yt.videos.get(VideoId(videoId));
    return VideoInfo(
      id: v.id.value,
      title: v.title,
      author: v.author,
      duration: v.duration,
      thumbnailUrl: v.thumbnails.highResUrl,
    );
  }

  @override
  Stream<MediaStream> candidates(
    String videoId,
    DownloadKind kind, {
    int? height,
  }) async* {
    for (final client in _clients) {
      StreamManifest manifest;
      try {
        manifest = await _yt.videos.streamsClient
            .getManifest(VideoId(videoId), ytClients: [client])
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        debugPrint('client #${_clients.indexOf(client)} manifest failed: $e');
        continue;
      }
      debugPrint(
        'manifest ok: audio=${manifest.audioOnly.length} muxed=${manifest.muxed.length}',
      );
      final List<StreamInfo> options;
      if (kind == DownloadKind.audio) {
        // Audio-only streams usually answer 403, so the muxed stream comes first
        // (ffmpeg drops the video track).
        final audio = manifest.audioOnly.sortByBitrate().reversed.toList()
          ..sort(
            (a, b) => (a.container.name == 'mp4' ? 0 : 1).compareTo(
              b.container.name == 'mp4' ? 0 : 1,
            ),
          );
        options = [...manifest.muxed, ...audio];
      } else {
        options = manifest.muxed.sortByVideoQuality().reversed.toList();
        // Muxed streams only reach 360p, so higher qualities use video-only
        // streams that the service merges with an audio track. Above 1080p
        // YouTube only offers VP9/AV1, often as webm; the merge writes mp4.
        final wanted = height ?? 0;
        if (wanted > 360) {
          final byHeight =
              manifest.videoOnly
                  .where(
                    (s) =>
                        (s.container.name == 'mp4' ||
                            (wanted > 1080 && s.container.name == 'webm')) &&
                        s.videoResolution.height <= wanted &&
                        s.videoResolution.height > 360,
                  )
                  .toList()
                ..sort((a, b) {
                  final h = b.videoResolution.height.compareTo(
                    a.videoResolution.height,
                  );
                  if (h != 0) return h;
                  return (a.videoCodec.startsWith('avc1') ? 0 : 1).compareTo(
                    b.videoCodec.startsWith('avc1') ? 0 : 1,
                  );
                });
          for (final v in byHeight.take(2)) {
            yield MediaStream(
              container: v.container.name,
              totalBytes: v.size.totalBytes,
              videoOnly: true,
              height: v.videoResolution.height,
              open: () => rangedDownload(v.url, v.size.totalBytes),
            );
          }
        }
      }
      for (final info in options) {
        yield MediaStream(
          container: info.container.name,
          totalBytes: info.size.totalBytes,
          open: () => rangedDownload(info.url, info.size.totalBytes),
        );
      }
    }
  }

  static const _userAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

  /// YouTube rejects open-ended requests (403) but serves ranged ones, so the
  /// file is fetched in fixed-size chunks.
  static Stream<List<int>> rangedDownload(
    Uri url,
    int total, {
    int chunk = 1 << 20,
    http.Client? client,
  }) async* {
    final c = client ?? http.Client();
    try {
      var start = 0;
      while (start < total) {
        final end = (start + chunk - 1).clamp(0, total - 1);
        final res = await c.get(
          url,
          headers: {'Range': 'bytes=$start-$end', 'User-Agent': _userAgent},
        );
        if (res.statusCode != 200 && res.statusCode != 206) {
          throw HttpException('HTTP ${res.statusCode}');
        }
        yield res.bodyBytes;
        start += res.bodyBytes.length;
        if (res.bodyBytes.isEmpty) break;
      }
    } finally {
      if (client == null) c.close();
    }
  }

  @override
  void close() => _yt.close();
}
