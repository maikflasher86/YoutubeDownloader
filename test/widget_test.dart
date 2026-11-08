import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/main.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/download_service.dart';
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
  Stream<MediaStream> candidates(String videoId, DownloadKind kind,
          {int? height}) =>
      Stream.value(MediaStream(
        container: 'mp4',
        totalBytes: 3,
        open: () => Stream.value([1, 2, 3]),
      ));

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
  Future<SavedFile> save(File file, {required bool audio}) async =>
      SavedFile(location: 'Music/x.mp3', uri: Uri.parse('content://x/1'), mime: 'audio/mpeg');
}

class _Shared implements SharedTextSource {
  final controller = StreamController<String>();
  @override
  Future<String?> initial() async => null;
  @override
  Stream<String> get stream => controller.stream;
}

void main() {
  late Directory tmp;
  late _Shared shared;
  late AppState state;
  final opened = <SavedFile>[];

  setUp(() {
    opened.clear();
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
    );
  });

  Future<void> pump(WidgetTester t) => t
      .pumpWidget(YoutubeDownloaderApp(
          state: state, settings: AppSettings(), sharedText: shared));

  testWidgets('shows error for invalid link', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('urlField')), 'hello');
    await t.tap(find.byKey(const Key('loadButton')));
    await t.pump();
    expect(find.byKey(const Key('errorText')), findsOneWidget);
  });

  testWidgets('loads a pasted link and downloads mp3', (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('urlField')),
        'https://www.youtube.com/watch?v=Jc10TXOh-yM&list=RDJc10TXOh-yM');
    await t.tap(find.byKey(const Key('loadButton')));
    await t.pumpAndSettle();
    expect(find.text('Test Song'), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('mp3Button')));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('mp3Button')));
      for (var i = 0; i < 50; i++) {
        if (state.downloads.first.status != DownloadStatus.running) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await t.pump();
    expect(state.downloads.first.error, isNull);
    expect(state.downloads.first.status, DownloadStatus.done);
    expect(state.downloads.first.savedPath, 'Music/x.mp3');

    await t.scrollUntilVisible(find.byKey(const Key('downloadTile')), 200);
    await t.tap(find.byKey(const Key('downloadTile')));
    await t.pump();
    expect(opened.single.uri.toString(), 'content://x/1');
  });

  testWidgets('a shared link is loaded automatically', (t) async {
    await pump(t);
    shared.controller.add('Check https://youtu.be/Jc10TXOh-yM');
    await t.pumpAndSettle();
    expect(find.text('Test Song'), findsOneWidget);
  });
}
