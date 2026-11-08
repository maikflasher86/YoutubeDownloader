import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:integration_test/integration_test.dart';
import 'package:youtube_downloader/main.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/shared_text.dart';
import 'package:youtube_downloader/services/youtube_source.dart';
import 'package:youtube_downloader/ui/app_state.dart';

class _Converter implements AudioConverter {
  @override
  Future<void> toMp3(String input, String output) async {}

  @override
  Future<void> mux(String video, String audio, String output) async {}
}

class _Saver implements FileSaver {
  @override
  Future<SavedFile> save(File file, {required bool audio}) =>
      throw UnimplementedError();
}

class _NoShare implements SharedTextSource {
  @override
  Future<String?> initial() async => null;
  @override
  Stream<String> get stream => const Stream.empty();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('opens the preview of several search results', (t) async {
    final state = AppState(
      DownloadService(
        source: ExplodeYoutubeSource(),
        converter: _Converter(),
        saver: _Saver(),
        tempDir: Directory.systemTemp,
      ),
      opener: (f) async {},
    );
    await t.pumpWidget(
      YoutubeDownloaderApp(
        state: state,
        settings: AppSettings(),
        sharedText: _NoShare(),
      ),
    );
    await t.enterText(find.byKey(const Key('searchField')), 'let it go');
    await t.tap(find.byKey(const Key('searchButton')));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 500));
      if (find.byKey(const Key('searchResult1')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const Key('searchResult1')), findsOneWidget);

    for (final i in [0, 1, 0]) {
      await t.tap(find.byKey(Key('searchResult$i')));
      for (var s = 0; s < 16; s++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      await t.tap(find.byType(BackButton));
      await t.pump(const Duration(seconds: 2));
    }
  });
}
