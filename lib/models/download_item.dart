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

enum DownloadStatus { running, done, failed }

class DownloadItem {
  DownloadItem({
    required this.info,
    required this.kind,
    this.status = DownloadStatus.running,
    this.progress = 0,
    this.stage = 'Starting',
    this.saved,
    this.error,
    this.height,
  });

  final VideoInfo info;
  final DownloadKind kind;

  /// Requested video height in pixels, null for audio.
  final int? height;
  DownloadStatus status;
  double progress;
  String stage;
  SavedFile? saved;
  String? error;

  String? get savedPath => saved?.location;
}
