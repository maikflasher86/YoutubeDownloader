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

  test('retains failed downloads and resumes unfinished downloads', () async {
    final service = DownloadService(
      source: _ResumeSource(),
      converter: _NoConverter(),
      saver: _ResumeSaver(),
      tempDir: Directory.systemTemp,
    );
    final first = AppState(service, opener: (_) async {}, persist: true);
    first.downloads.addAll([
      DownloadItem(
        info: const VideoInfo(
          id: 'unfinished',
          title: 'Unfinished video',
          author: 'Artist',
          thumbnailUrl: '',
        ),
        kind: DownloadKind.video,
        status: DownloadStatus.running,
        stage: DownloadStage.downloading,
      ),
      DownloadItem(
        info: const VideoInfo(
          id: 'failed',
          title: 'Failed video',
          author: 'Artist',
          thumbnailUrl: '',
        ),
        kind: DownloadKind.video,
        status: DownloadStatus.failed,
        error: 'Network error',
      ),
    ]);
    await first.saveHistory();

    final second = AppState(service, opener: (_) async {}, persist: true);
    await second.loadHistory();
    for (var i = 0; i < 100; i++) {
      if (second.downloads.any(
        (item) =>
            item.info.id == 'unfinished' && item.status == DownloadStatus.done,
      )) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(second.downloads, hasLength(2));
    expect(
      second.downloads.singleWhere((item) => item.info.id == 'failed').status,
      DownloadStatus.failed,
    );
    expect(second.isAdded('unfinished', DownloadKind.video), isTrue);

    final third = AppState(service, opener: (_) async {}, persist: true);
    await third.loadHistory();
    expect(third.downloads, hasLength(1));
    expect(third.downloads.single.info.id, 'failed');
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

class _ResumeSource implements YoutubeSource {
  @override
  Future<VideoInfo> getInfo(String videoId) async => VideoInfo(
    id: videoId,
    title: 'Resumed video',
    author: 'Artist',
    thumbnailUrl: '',
  );

  @override
  Future<String> previewUrl(String videoId) async => '';

  @override
  Future<List<VideoInfo>> search(String query) async => [];

  @override
  Stream<MediaStream> candidates(
    String videoId,
    DownloadKind kind, {
    int? height,
  }) => Stream.value(
    MediaStream(
      container: 'mp4',
      totalBytes: 3,
      open: () => Stream.value([1, 2, 3]),
    ),
  );

  @override
  void close() {}
}

class _ResumeSaver implements FileSaver {
  @override
  Future<SavedFile> save(File file, {required bool audio}) async => SavedFile(
    location: 'Movies/resumed.mp4',
    uri: Uri.parse('content://x/resumed'),
    mime: 'video/mp4',
  );
}
