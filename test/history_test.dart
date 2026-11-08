import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/youtube_source.dart';
import 'package:youtube_downloader/ui/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('finished downloads survive an app restart', () async {
    final service = DownloadService(
      source: _NoSource(),
      converter: _NoConverter(),
      saver: _NoSaver(),
      tempDir: Directory.systemTemp,
    );
    final first = AppState(service, opener: (_) async {}, persist: true);
    first.downloads.add(
      DownloadItem(
        info: const VideoInfo(
          id: 'abc',
          title: 'Song',
          author: 'Artist',
          duration: Duration(seconds: 90),
          thumbnailUrl: 'http://x/t.jpg',
        ),
        kind: DownloadKind.audio,
        status: DownloadStatus.done,
        saved: SavedFile(
          location: 'Music/Song.mp3',
          uri: Uri.parse('content://x/1'),
          mime: 'audio/mpeg',
        ),
      ),
    );
    await first.saveHistory();

    final second = AppState(service, opener: (_) async {}, persist: true);
    await second.loadHistory();

    expect(second.downloads, hasLength(1));
    final d = second.downloads.single;
    expect(d.info.title, 'Song');
    expect(d.info.duration, const Duration(seconds: 90));
    expect(d.status, DownloadStatus.done);
    expect(d.saved?.uri, Uri.parse('content://x/1'));
    expect(second.isAdded('abc', DownloadKind.audio), isTrue);
    expect(second.isAdded('abc', DownloadKind.video), isFalse);
  });
}

class _NoSource implements YoutubeSource {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _NoConverter implements AudioConverter {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _NoSaver implements FileSaver {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
