/// Selectable video qualities.
enum VideoQuality {
  resolution720p(720, '720p'),
  resolution1080p(1080, '1080p'),
  resolution2K(1440, '2K'),
  resolution4K(2160, '4K'),
  resolution8K(4320, '8K');

  const VideoQuality(this.height, this.label);

  /// Wanted maximum height in pixels.
  final int height;
  final String label;

  static const defaultQuality = resolution1080p;

  /// The quality for a stored [height], or null when unknown.
  static VideoQuality? fromHeight(int? height) {
    for (final q in values) {
      if (q.height == height) return q;
    }
    return null;
  }
}
