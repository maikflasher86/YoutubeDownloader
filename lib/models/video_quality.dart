/// Selectable video qualities.
enum VideoQuality {
  p720(720, '720p'),
  p1080(1080, '1080p'),
  k2(1440, '2K'),
  k4(2160, '4K'),
  k8(4320, '8K');

  const VideoQuality(this.height, this.label);

  /// Wanted maximum height in pixels.
  final int height;
  final String label;

  static const defaultQuality = p1080;

  /// The quality for a stored [height], or null when unknown.
  static VideoQuality? fromHeight(int? height) {
    for (final q in values) {
      if (q.height == height) return q;
    }
    return null;
  }
}
