import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final _urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

/// Extracts the first YouTube video id from arbitrary text such as a shared
/// message ("Title https://youtu.be/xyz"). Returns null if none is found.
String? extractVideoId(String? text) {
  if (text == null) return null;
  for (final match in _urlPattern.allMatches(text)) {
    final id = VideoId.parseVideoId(match.group(0)!);
    if (id != null) return id;
  }
  return VideoId.parseVideoId(text.trim());
}

/// Removes characters that are not allowed in file names.
String sanitizeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final limited = cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
  return limited.isEmpty ? 'video' : limited;
}
