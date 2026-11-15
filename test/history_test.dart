import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/delete_file.dart';
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

  test('deleting a completed file removes its marker after restart', () async {
    final service = DownloadService(
      source: _NoSource(),
      converter: _NoConverter(),
      saver: _NoSaver(),
      tempDir: Directory.systemTemp,
    );
    final state = AppState(
      service,
      opener: (_) async {},
      persist: true,
      deleter: (_) async {},
    );
    final item = DownloadItem(
      info: const VideoInfo(
        id: 'abc',
        title: 'Song',
        author: '',
        thumbnailUrl: '',
      ),
      kind: DownloadKind.audio,
      status: DownloadStatus.done,
      saved: SavedFile(
        location: 'Song.mp3',
        uri: Uri.parse('content://x/1'),
        mime: 'audio/mpeg',
      ),
    );
    state.downloads.add(item);
    await state.saveHistory();
    await state.delete(item);
    final restored = AppState(service, opener: (_) async {}, persist: true);
    await restored.loadHistory();
    expect(state.downloads, isEmpty);
    expect(restored.isAdded('abc', DownloadKind.audio), isFalse);
  });

  test(
    'duplicate references are removed and other files keep their marker',
    () async {
      final service = DownloadService(
        source: _NoSource(),
        converter: _NoConverter(),
        saver: _NoSaver(),
        tempDir: Directory.systemTemp,
      );
      final state = AppState(
        service,
        opener: (_) async {},
        persist: true,
        deleter: (_) async {},
      );
      DownloadItem item(String id, String uri) => DownloadItem(
        info: VideoInfo(id: id, title: id, author: '', thumbnailUrl: ''),
        kind: DownloadKind.audio,
        status: DownloadStatus.done,
        saved: SavedFile(
          location: uri,
          uri: Uri.parse(uri),
          mime: 'audio/mpeg',
        ),
      );
      final first = item('abc', 'content://x/1');
      final duplicate = item('other', 'content://x/1');
      final otherFile = item('abc', 'content://x/2');
      state.downloads.addAll([first, duplicate, otherFile]);
      await state.saveHistory();
      await state.delete(first);
      expect(state.downloads, [otherFile]);
      final restored = AppState(service, opener: (_) async {}, persist: true);
      await restored.loadHistory();
      expect(restored.isAdded('abc', DownloadKind.audio), isTrue);
      expect(restored.isAdded('other', DownloadKind.audio), isFalse);
    },
  );

  test('keeps older markers and keeps records when deletion fails', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadedItems', '[{"id":"abc","kind":"audio"}]');
    final service = DownloadService(
      source: _NoSource(),
      converter: _NoConverter(),
      saver: _NoSaver(),
      tempDir: Directory.systemTemp,
    );
    var fail = true;
    final state = AppState(
      service,
      opener: (_) async {},
      persist: true,
      deleter: (_) async {
        if (fail) throw const DeleteFailure(DeleteFailureKind.missing);
      },
    );
    await state.loadHistory();
    final item = DownloadItem(
      info: const VideoInfo(
        id: 'abc',
        title: 'Song',
        author: '',
        thumbnailUrl: '',
      ),
      kind: DownloadKind.audio,
      status: DownloadStatus.done,
      saved: SavedFile(
        location: 'Song',
        uri: Uri.parse('content://x/1'),
        mime: 'audio/mpeg',
      ),
    );
    state.downloads.add(item);
    await expectLater(state.delete(item), throwsA(isA<DeleteFailure>()));
    expect(state.downloads, [item]);
    fail = false;
    await state.delete(item);
    final restored = AppState(service, opener: (_) async {}, persist: true);
    await restored.loadHistory();
    expect(restored.isAdded('abc', DownloadKind.audio), isTrue);
  });

  test('does not delete while a download is active', () async {
    final service = DownloadService(
      source: _NoSource(),
      converter: _NoConverter(),
      saver: _NoSaver(),
      tempDir: Directory.systemTemp,
    );
    var called = false;
    final state = AppState(
      service,
      opener: (_) async {},
      deleter: (_) async {
        called = true;
      },
    );
    final info = const VideoInfo(
      id: 'abc',
      title: 'Song',
      author: '',
      thumbnailUrl: '',
    );
    final finished = DownloadItem(
      info: info,
      kind: DownloadKind.audio,
      status: DownloadStatus.done,
      saved: SavedFile(
        location: 'Song',
        uri: Uri.parse('content://x/1'),
        mime: 'audio/mpeg',
      ),
    );
    state.downloads.addAll([
      finished,
      DownloadItem(info: info, kind: DownloadKind.video),
    ]);
    await expectLater(
      state.delete(finished),
      throwsA(
        isA<DeleteFailure>().having(
          (e) => e.kind,
          'kind',
          DeleteFailureKind.busy,
        ),
      ),
    );
    expect(called, isFalse);
    expect(state.downloads, hasLength(2));
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
