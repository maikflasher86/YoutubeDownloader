import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/main.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/delete_file.dart';
import 'package:youtube_downloader/services/older_files.dart';
import 'package:youtube_downloader/services/shared_text.dart';
import 'package:youtube_downloader/services/youtube_source.dart';
import 'package:youtube_downloader/ui/app_state.dart';

class _Source implements YoutubeSource {
  @override
  Future<VideoInfo> getInfo(String videoId) async => VideoInfo(
    id: videoId,
    title: 'Test Song',
    author: 'Artist',
    duration: const Duration(minutes: 3, seconds: 46),
    thumbnailUrl: '',
  );

  @override
  Future<String> previewUrl(String videoId) async => 'http://localhost/v.mp4';

  @override
  Future<List<VideoInfo>> search(String query) async => [
    await getInfo('Jc10TXOh-yM'),
    await getInfo('dQw4w9WgXcQ'),
  ];

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

class _Converter implements AudioConverter {
  @override
  Future<void> toMp3(String input, String output) async =>
      File(output).writeAsBytesSync([1]);

  @override
  Future<void> mux(String video, String audio, String output) async =>
      File(output).writeAsBytesSync([1]);
}

class _Saver implements FileSaver {
  @override
  Future<SavedFile> save(File file, {required bool audio}) async => SavedFile(
    location: 'Music/x.mp3',
    uri: Uri.parse('content://x/1'),
    mime: 'audio/mpeg',
  );
}

class _Shared implements SharedTextSource {
  final controller = StreamController<String>();
  @override
  Future<String?> initial() async => null;
  @override
  Stream<String> get stream => controller.stream;
}

class _OlderFiles implements OlderFilesRepository {
  final files = <OlderFile>[
    OlderFile(
      name: 'Old song.mp3',
      audio: true,
      saved: SavedFile(
        uri: Uri.parse('content://provider/song'),
        location: 'Audio/Old song.mp3',
        mime: 'audio/mpeg',
      ),
    ),
    OlderFile(
      name: 'Old movie.mp4',
      audio: false,
      saved: SavedFile(
        uri: Uri.parse('content://provider/movie'),
        location: 'Video/Old movie.mp4',
        mime: 'video/mp4',
      ),
    ),
  ];
  int listCalls = 0;
  bool listFails = false;
  List<String> issues = [];
  bool deleteFails = false;
  int deleteCalls = 0;

  @override
  Future<OlderFilesResult> list() async {
    listCalls++;
    if (listFails) throw StateError('provider denied access');
    return OlderFilesResult(List.of(files), issues: issues);
  }

  @override
  Future<void> delete(OlderFile file) async {
    deleteCalls++;
    if (deleteFails) throw StateError('provider refused deletion');
    files.remove(file);
  }
}

void main() {
  late Directory tmp;
  late _Shared shared;
  late AppState state;
  final opened = <SavedFile>[];
  final deleted = <SavedFile>[];
  bool deleteFails = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opened.clear();
    deleted.clear();
    deleteFails = false;
    tmp = Directory.systemTemp.createTempSync('yt_widget');
    shared = _Shared();
    state = AppState(
      DownloadService(
        source: _Source(),
        converter: _Converter(),
        saver: _Saver(),
        tempDir: tmp,
      ),
      opener: (f) async => opened.add(f),
      deleter: (f) async {
        if (deleteFails) throw const DeleteFailure(DeleteFailureKind.missing);
        deleted.add(f);
      },
    );
  });

  Future<void> pump(
    WidgetTester t, {
    bool startOnDownloads = false,
    AppSettings? settings,
    OlderFilesRepository? olderFiles,
  }) async {
    await t.pumpWidget(
      YoutubeDownloaderApp(
        state: state,
        settings: settings ?? AppSettings(),
        sharedText: shared,
        olderFiles: olderFiles,
      ),
    );
    if (startOnDownloads) {
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tabDownloads')));
      await t.pumpAndSettle();
    }
  }

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('older files filter, open and confirm deletion ${size.width}', (
      t,
    ) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      final settings = AppSettings();
      await settings.setShowOlderFiles(true);
      final repository = _OlderFiles();
      await pump(
        t,
        startOnDownloads: true,
        settings: settings,
        olderFiles: repository,
      );
      await t.ensureVisible(find.byKey(const Key('searchOlderFiles')));
      await t.pumpAndSettle();
      expect(find.text('Old song.mp3'), findsOneWidget);
      expect(find.text('Old movie.mp4'), findsOneWidget);
      await t.tap(find.text('Audio'));
      await t.pumpAndSettle();
      expect(find.text('Old movie.mp4'), findsNothing);
      await t.tap(find.text('All'));
      await t.pumpAndSettle();
      expect(find.text('Old movie.mp4'), findsOneWidget);
      await t.enterText(find.byKey(const Key('searchOlderFiles')), 'song');
      await t.pumpAndSettle();
      expect(find.text('Old movie.mp4'), findsNothing);
      final tile = find.byKey(const ValueKey('older:content://provider/song'));
      await t.ensureVisible(tile);
      await t.tap(tile);
      await t.pump();
      expect(opened.single.uri.toString(), 'content://provider/song');
      await t.tap(
        find.descendant(of: tile, matching: find.byTooltip('Delete file')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repository.deleteCalls, 0);
      await t.tap(
        find.descendant(of: tile, matching: find.byTooltip('Delete file')),
      );
      await t.pumpAndSettle();
      repository.deleteFails = true;
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(repository.deleteCalls, 1);
      expect(find.text('Old song.mp3'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      repository.deleteFails = false;
      await t.tap(
        find.descendant(of: tile, matching: find.byTooltip('Delete file')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(repository.deleteCalls, 2);
      expect(find.text('Old song.mp3'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('older files stay disabled and provider errors are visible', (
    t,
  ) async {
    final settings = AppSettings();
    final repository = _OlderFiles()..listFails = true;
    await pump(
      t,
      startOnDownloads: true,
      settings: settings,
      olderFiles: repository,
    );
    expect(repository.listCalls, 0);
    await settings.setShowOlderFiles(true);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('olderFilesError')));
    expect(find.textContaining('provider denied access'), findsOneWidget);
  });

  testWidgets('a missing folder is reported without hiding other files', (
    t,
  ) async {
    final settings = AppSettings();
    await settings.setShowOlderFiles(true);
    final repository = _OlderFiles()..issues = ['Video folder missing'];
    await pump(
      t,
      startOnDownloads: true,
      settings: settings,
      olderFiles: repository,
    );
    await t.ensureVisible(find.byKey(const Key('olderFilesWarning')));
    await t.pumpAndSettle();
    expect(find.textContaining('Video folder missing'), findsOneWidget);
    expect(find.text('Old song.mp3'), findsOneWidget);
  });

  testWidgets('current session files do not appear in older files', (t) async {
    final settings = AppSettings();
    await settings.setShowOlderFiles(true);
    final repository = _OlderFiles();
    state.downloads.add(
      DownloadItem(
        info: const VideoInfo(
          id: 'song',
          title: 'Current song',
          author: '',
          thumbnailUrl: '',
        ),
        kind: DownloadKind.audio,
        status: DownloadStatus.done,
        saved: repository.files.first.saved,
      ),
    );
    await pump(
      t,
      startOnDownloads: true,
      settings: settings,
      olderFiles: repository,
    );
    await t.ensureVisible(find.byKey(const Key('searchOlderFiles')));
    await t.pumpAndSettle();
    expect(find.text('Old song.mp3'), findsNothing);
    expect(find.text('Old movie.mp4'), findsOneWidget);
  });

  test('a removed session file does not prevent identity checks', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}removed.mp3');
    await file.writeAsString('fixture');
    state.downloads.add(
      DownloadItem(
        info: const VideoInfo(
          id: 'song',
          title: 'Current song',
          author: '',
          thumbnailUrl: '',
        ),
        kind: DownloadKind.audio,
        status: DownloadStatus.done,
        saved: SavedFile(
          location: file.path,
          uri: file.uri,
          mime: 'audio/mpeg',
        ),
      ),
    );
    await file.delete();
    expect(await state.currentFileIdentities(), hasLength(1));
  });

  test('older-file deletion refuses current and pending downloads', () async {
    final saved = SavedFile(
      location: 'Audio/song.mp3',
      uri: Uri.parse('content://provider/song'),
      mime: 'audio/mpeg',
    );
    final current = DownloadItem(
      info: const VideoInfo(
        id: 'song',
        title: 'Current song',
        author: '',
        thumbnailUrl: '',
      ),
      kind: DownloadKind.audio,
      status: DownloadStatus.done,
      saved: saved,
    );
    state.downloads.add(current);
    var called = false;
    await expectLater(
      state.deleteOlder(saved, () async => called = true),
      throwsA(isA<DeleteFailure>()),
    );
    expect(called, isFalse);
    current.status = DownloadStatus.queued;
    await expectLater(
      state.deleteOlder(saved, () async => called = true),
      throwsA(
        isA<DeleteFailure>().having(
          (error) => error.kind,
          'kind',
          DeleteFailureKind.busy,
        ),
      ),
    );
    expect(called, isFalse);
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('delete action confirms and fits ${size.width}', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      state.downloads.add(
        DownloadItem(
          info: const VideoInfo(
            id: 'abc',
            title: 'Test Song',
            author: '',
            thumbnailUrl: '',
          ),
          kind: DownloadKind.audio,
          status: DownloadStatus.done,
          saved: SavedFile(
            location: 'Music/x.mp3',
            uri: Uri.parse('content://x/1'),
            mime: 'audio/mpeg',
          ),
        ),
      );
      await pump(t, startOnDownloads: true);
      await t.ensureVisible(find.byKey(const Key('deleteDownload')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('deleteDownload')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(state.downloads, hasLength(1));
      await t.tap(find.byKey(const Key('deleteDownload')));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(deleted, hasLength(1));
      expect(state.downloads, isEmpty);
      expect(t.takeException(), isNull);
    });
    testWidgets('workspace navigation fits ${size.width}', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await pump(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      if (size.width < 800) {
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          1,
        );
      }

      await t.tap(find.byKey(const Key('tabDownloads')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('urlField')), findsOneWidget);
      expect(find.byKey(const Key('tabDownloads')), findsOneWidget);
      await t.tap(find.byKey(const Key('tabSearch')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      await t.tap(find.byKey(const Key('tabDownloads')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('urlField')), findsOneWidget);
      await t.tap(find.byKey(const Key('batchButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('batchField')), findsOneWidget);
      await t.tap(find.byKey(const Key('settingsButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('folderTile')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('shows a missing-file error and keeps the download', (t) async {
    deleteFails = true;
    state.downloads.add(
      DownloadItem(
        info: const VideoInfo(
          id: 'abc',
          title: 'Test Song',
          author: '',
          thumbnailUrl: '',
        ),
        kind: DownloadKind.audio,
        status: DownloadStatus.done,
        saved: SavedFile(
          location: 'Music/x.mp3',
          uri: Uri.parse('content://x/1'),
          mime: 'audio/mpeg',
        ),
      ),
    );
    await pump(t, startOnDownloads: true);
    await t.ensureVisible(find.byKey(const Key('deleteDownload')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('deleteDownload')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pump();
    expect(
      find.text('The file no longer exists. The download remains in the list.'),
      findsOneWidget,
    );
    expect(state.downloads, hasLength(1));
  });

  testWidgets('resizing keeps the link and selected format', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pump(t, startOnDownloads: true);
    await t.enterText(
      find.byKey(const Key('urlField')),
      'https://youtu.be/Jc10TXOh-yM',
    );
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('formatSelector')),
        matching: find.text('MP3'),
      ),
    );
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byKey(const Key('urlField'))).controller!.text,
      'https://youtu.be/Jc10TXOh-yM',
    );
    expect(
      t
          .widget<SegmentedButton<DownloadKind>>(
            find.byKey(const Key('formatSelector')),
          )
          .selected,
      {DownloadKind.audio},
    );
  });

  testWidgets('shows error for invalid link', (t) async {
    await pump(t, startOnDownloads: true);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('loadButton'))).onPressed,
      isNull,
    );
    await t.enterText(find.byKey(const Key('urlField')), 'hello');
    await t.pump();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('loadButton'))).onPressed,
      isNull,
    );
    await t.enterText(
      find.byKey(const Key('urlField')),
      'https://youtu.be/Jc10TXOh-yM',
    );
    await t.pump();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('loadButton'))).onPressed,
      isNotNull,
    );
    await t.enterText(find.byKey(const Key('urlField')), 'hello');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.go);
    await t.pump();
    expect(find.byKey(const Key('errorText')), findsOneWidget);
  });

  testWidgets('loads a pasted link and downloads mp3', (t) async {
    await pump(t, startOnDownloads: true);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('formatSelector')),
        matching: find.text('MP3'),
      ),
    );
    await t.pump();
    await t.enterText(
      find.byKey(const Key('urlField')),
      'https://www.youtube.com/watch?v=Jc10TXOh-yM&list=RDJc10TXOh-yM',
    );
    await t.pump();
    await t.tap(find.byKey(const Key('loadButton')));
    await t.pumpAndSettle();
    expect(find.text('Test Song'), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('downloadButton')));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('downloadButton')));
      for (var i = 0; i < 50; i++) {
        if (state.downloads.first.status != DownloadStatus.running) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await t.pump();
    expect(state.downloads.first.error, isNull);
    expect(state.downloads.first.status, DownloadStatus.done);
    expect(state.downloads.first.savedPath, 'Music/x.mp3');

    await t.ensureVisible(find.byKey(const Key('downloadTile')));
    await t.pump();
    await t.tap(find.byKey(const Key('downloadTile')));
    await t.pump();
    expect(opened.single.uri.toString(), 'content://x/1');
  });

  testWidgets('downloads video with the selected quality', (t) async {
    await pump(t, startOnDownloads: true);
    await t.enterText(
      find.byKey(const Key('urlField')),
      'https://youtu.be/Jc10TXOh-yM',
    );
    await t.pump();
    await t.tap(find.byKey(const Key('qualityDropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('720p').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('loadButton')));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('downloadButton')));
      for (var i = 0; i < 50; i++) {
        if (state.downloads.first.status != DownloadStatus.running) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await t.pump();
    expect(state.downloads.single.kind, DownloadKind.video);
    expect(state.downloads.single.height, 720);
    expect(state.downloads.single.status, DownloadStatus.done);
    await t.enterText(
      find.byKey(const Key('urlField')),
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await t.pump();
    expect(find.byKey(const Key('downloadButton')), findsNothing);
    expect(find.byKey(const Key('loadButton')), findsOneWidget);
  });

  testWidgets('batch downloads every pasted link', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('batchButton')));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('batchStartButton')))
          .onPressed,
      isNull,
    );
    await t.enterText(
      find.byKey(const Key('batchField')),
      'https://youtu.be/Jc10TXOh-yM\nhttps://youtu.be/dQw4w9WgXcQ',
    );
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('batchStartButton')));
      for (var i = 0; i < 100; i++) {
        if (state.downloads.length == 2 &&
            state.downloads.every((d) => d.status != DownloadStatus.running)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await t.pumpAndSettle();
    expect(state.downloads, hasLength(2));
    expect(
      state.downloads.map((d) => d.stage),
      everyElement(DownloadStage.saved),
    );
    expect(
      state.downloads.map((d) => d.status),
      everyElement(DownloadStatus.done),
    );
    expect(
      state.downloads.map((d) => d.kind),
      everyElement(DownloadKind.audio),
    );
  });

  test('batch runs 3 downloads in parallel and queues the rest', () async {
    final future = state.startBatch(
      'https://youtu.be/Jc10TXOh-yM\nhttps://youtu.be/dQw4w9WgXcQ\n'
      'https://youtu.be/9bZkp7q19f0\nhttps://youtu.be/kJQP7kiw5Fk',
      DownloadKind.audio,
    );
    expect(state.downloads.map((d) => d.status), [
      DownloadStatus.running,
      DownloadStatus.running,
      DownloadStatus.running,
      DownloadStatus.queued,
    ]);
    expect(state.downloads.last.stage, DownloadStage.queued);
    await future;
    expect(
      state.downloads.map((d) => d.status),
      everyElement(DownloadStatus.done),
    );
  });

  testWidgets('search results can be added to the queue', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('tabSearch')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('searchField')), 'let it go');
    await t.tap(find.byKey(const Key('searchButton')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('searchResult1')), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('searchMp30')));
      for (var i = 0; i < 100; i++) {
        if (state.downloads.every((d) => d.status == DownloadStatus.done)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await t.pump();
    expect(state.downloads, hasLength(1));
    expect(state.downloads.single.status, DownloadStatus.done);
    expect(state.downloads.single.kind, DownloadKind.audio);
    final mp3 = t.widget<IconButton>(find.byKey(const Key('searchMp30')));
    final video = t.widget<IconButton>(find.byKey(const Key('searchVideo0')));
    expect(mp3.onPressed, isNull);
    expect(video.onPressed, isNotNull);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a shared link is loaded automatically', (t) async {
    await pump(t);
    shared.controller.add('Check https://youtu.be/Jc10TXOh-yM');
    await t.pumpAndSettle();
    expect(find.text('Test Song'), findsOneWidget);
  });
}
