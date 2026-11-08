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
  static final Map<String, VideoQuality> _byName = {
    for (final quality in values) quality.name: quality,
  };

  /// The quality for a stored enum [name], or the default when unknown.
  static VideoQuality fromName(String? name) {
    return _byName[name] ?? defaultQuality;
  }
}
