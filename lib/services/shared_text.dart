import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Emits shared text when the user shares a link to this app.
abstract class SharedTextSource {
  Future<String?> initial();
  Stream<String> get stream;
}

/// Desktop has no share sheet; links are pasted instead.
class NoSharedTextSource implements SharedTextSource {
  @override
  Future<String?> initial() async => null;

  @override
  Stream<String> get stream => const Stream.empty();
}

class PluginSharedTextSource implements SharedTextSource {
  @override
  Future<String?> initial() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    ReceiveSharingIntent.instance.reset();
    return _firstText(media);
  }

  @override
  Stream<String> get stream => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_firstText)
      .where((t) => t != null)
      .cast<String>();

  static String? _firstText(List<SharedMediaFile> media) {
    for (final m in media) {
      if (m.type == SharedMediaType.text || m.type == SharedMediaType.url) {
        return m.path;
      }
    }
    return null;
  }
}
