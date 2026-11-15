import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/youtube_source.dart';
import 'package:youtube_downloader/ui/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('download list clears while completed items stay marked', () async {
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

    expect(second.downloads, isEmpty);
    expect(second.isAdded('abc', DownloadKind.audio), isTrue);
    expect(second.isAdded('abc', DownloadKind.video), isFalse);
  });

  test('migrates previously saved history to completed item markers', () async {
    final prefs = await SharedPreferences.getInstance();
    final item = DownloadItem(
      info: const VideoInfo(
        id: 'legacy',
        title: 'Old Song',
        author: 'Artist',
        thumbnailUrl: '',
      ),
      kind: DownloadKind.audio,
      status: DownloadStatus.done,
      saved: SavedFile(
        location: 'Music/Old Song.mp3',
        uri: Uri.parse('content://x/2'),
        mime: 'audio/mpeg',
      ),
    );
    await prefs.setString('downloadHistory', jsonEncode([item.toJson()]));

    final state = AppState(
      DownloadService(
        source: _NoSource(),
        converter: _NoConverter(),
        saver: _NoSaver(),
        tempDir: Directory.systemTemp,
      ),
      opener: (_) async {},
      persist: true,
    );
    await state.loadHistory();

    expect(state.downloads, isEmpty);
    expect(state.isAdded('legacy', DownloadKind.audio), isTrue);
    expect(prefs.containsKey('downloadHistory'), isFalse);
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
