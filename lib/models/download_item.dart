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
}
