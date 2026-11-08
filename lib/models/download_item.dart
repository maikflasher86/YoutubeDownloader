import '../services/download_service.dart';

enum DownloadKind { video, audio }

class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'duration': duration?.inSeconds,
    'thumbnailUrl': thumbnailUrl,
  };

  factory VideoInfo.fromJson(Map<String, dynamic> j) => VideoInfo(
    id: j['id'] as String,
    title: j['title'] as String,
    author: j['author'] as String,
    duration: j['duration'] == null
        ? null
        : Duration(seconds: j['duration'] as int),
    thumbnailUrl: j['thumbnailUrl'] as String,
  );
}

enum DownloadStatus { queued, running, done, failed }

/// Progress step of a download; the UI translates it.
enum DownloadStage {
  queued,
  starting,
  downloading,
  downloadingVideo,
  downloadingAudio,
  converting,
  merging,
  saving,
  saved,
}

class DownloadItem {
  DownloadItem({
    required this.info,
    required this.kind,
    this.status = DownloadStatus.running,
    this.progress = 0,
    this.stage = DownloadStage.starting,
    this.saved,
    this.error,
    this.height,
  });

  VideoInfo info;
  final DownloadKind kind;

  /// Requested video height in pixels, null for audio.
  final int? height;
  DownloadStatus status;
  double progress;
  DownloadStage stage;
  SavedFile? saved;
  String? error;

  String? get savedPath => saved?.location;

  Map<String, dynamic> toJson() => {
    'info': info.toJson(),
    'kind': kind.name,
    'height': height,
    'saved': saved?.toJson(),
  };

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
    info: VideoInfo.fromJson(j['info'] as Map<String, dynamic>),
    kind: DownloadKind.values.byName(j['kind'] as String),
    height: j['height'] as int?,
    status: DownloadStatus.done,
    progress: 1,
    stage: DownloadStage.saved,
    saved: j['saved'] == null
        ? null
        : SavedFile.fromJson(j['saved'] as Map<String, dynamic>),
  );
}
