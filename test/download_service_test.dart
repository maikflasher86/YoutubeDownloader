import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/youtube_source.dart';
import 'package:youtube_downloader/ui/app_state.dart';

const info = VideoInfo(
  id: 'Jc10TXOh-yM',
  title: 'Song: Test/1',
  author: 'Artist',
  thumbnailUrl: '',
);

class FakeSource implements YoutubeSource {
  FakeSource(this.streams);
  final List<MediaStream> streams;

  @override
  Future<VideoInfo> getInfo(String videoId) async => info;

  @override
  Future<String> previewUrl(String videoId) async => 'http://localhost/v.mp4';

  @override
  Future<List<VideoInfo>> search(String query) async => [info];

  @override
  Stream<MediaStream> candidates(
    String videoId,
    DownloadKind kind, {
    int? height,
  }) => Stream.fromIterable(streams);

  @override
  void close() {}
}

class FakeConverter implements AudioConverter {
  bool failMux = false;
  bool failConversion = false;
  int? threshold;
  final thresholds = <int?>[];
  final muxed = <String>[];

  @override
  Future<void> toMp3(
    String input,
    String output, {
    int? silenceThresholdDb,
  }) async {
    threshold = silenceThresholdDb;
    thresholds.add(silenceThresholdDb);
    if (failConversion) throw Exception('silence detection failed');
    File(output).writeAsBytesSync(File(input).readAsBytesSync());
  }

  @override
  Future<void> mux(String video, String audio, String output) async {
    if (failMux) throw Exception('mux failed');
    muxed.add(
      '${video.split(Platform.pathSeparator).last}+${audio.split(Platform.pathSeparator).last}',
    );
    File(output).writeAsBytesSync([1]);
  }
}

class FakeSaver implements FileSaver {
  final saved = <String>[];
  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    saved.add('${audio ? 'audio' : 'video'}:${file.uri.pathSegments.last}');
    return SavedFile(
      location: 'Music/${file.uri.pathSegments.last}',
      mime: 'audio/mpeg',
    );
  }
}

MediaStream okStream(String container) => MediaStream(
  container: container,
  totalBytes: 6,
  open: () => Stream.fromIterable([
    [1, 2, 3],
    [4, 5, 6],
  ]),
);

MediaStream failing() => MediaStream(
  container: 'mp4',
  totalBytes: 6,
  open: () => Stream.error(Exception('403')),
);

MediaStream stalled() => MediaStream(
  container: 'mp4',
  totalBytes: 6,
  open: () => StreamController<List<int>>().stream,
);

void main() {
  late Directory tmp;
  late FakeSaver saver;
  late FakeConverter converter;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('yt_test');
    saver = FakeSaver();
    converter = FakeConverter();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  DownloadService build(List<MediaStream> streams) => DownloadService(
    source: FakeSource(streams),
    converter: converter,
    saver: saver,
    tempDir: tmp,
    stallTimeout: const Duration(milliseconds: 100),
  );

  MediaStream videoOnly(int h, [String container = 'mp4']) => MediaStream(
    container: container,
    totalBytes: 6,
    videoOnly: true,
    height: h,
    open: () => Stream.value([1, 2, 3, 4, 5, 6]),
  );

  test('merges a webm video-only stream (4K) into an mp4 file', () async {
    await build([videoOnly(2160, 'webm'), okStream('mp4')])
        .download(info, DownloadKind.video, height: 2160);
    expect(converter.muxed, ['Song_ Test_1.video.webm+Song_ Test_1.audio.m4a']);
    expect(saver.saved, ['video:Song_ Test_1.mp4']);
    expect(tmp.listSync(), isEmpty);
  });

  test('merges a video-only stream with audio for higher qualities', () async {
    await build([videoOnly(720), okStream('mp4')])
        .download(info, DownloadKind.video, height: 720);
    expect(converter.muxed, ['Song_ Test_1.video.mp4+Song_ Test_1.audio.m4a']);
    expect(saver.saved, ['video:Song_ Test_1.mp4']);
    expect(tmp.listSync(), isEmpty);
  });

  test('falls back to the muxed stream when merging fails', () async {
    converter.failMux = true;
    await build([videoOnly(720), okStream('mp4')])
        .download(info, DownloadKind.video, height: 720);
    expect(saver.saved, ['video:Song_ Test_1.mp4']);
    expect(tmp.listSync(), isEmpty);
  });

  test('fetchInfo rejects invalid links', () {
    expect(build([]).fetchInfo('nope'), throwsA(isA<DownloadException>()));
  });

  test('downloads audio, converts to mp3 and cleans temp files', () async {
    final progress = <DownloadStage>[];
    final path = await build(
      [okStream('mp4')],
    ).download(info, DownloadKind.audio, onProgress: (p, s) => progress.add(s));
    expect(path.location, 'Music/Song_ Test_1.mp3');
    expect(saver.saved, ['audio:Song_ Test_1.mp3']);
    expect(
      progress,
      containsAll([DownloadStage.downloading, DownloadStage.converting]),
    );
    expect(tmp.listSync(), isEmpty);
  });

  test('downloads video without conversion', () async {
    await build([okStream('mp4')]).download(info, DownloadKind.video);
    expect(saver.saved, ['video:Song_ Test_1.mp4']);
  });

  test(
    'passes the requested silence threshold to the audio converter',
    () async {
      await build([okStream('mp4')])
          .download(info, DownloadKind.audio, silenceThresholdDb: -45);
      expect(converter.threshold, -45);
    },
  );

  test('does not save when conversion fails', () async {
    converter.failConversion = true;
    await expectLater(
      build([okStream('mp4')])
          .download(info, DownloadKind.audio, silenceThresholdDb: -50),
      throwsA(isA<Exception>()),
    );
    expect(saver.saved, isEmpty);
    expect(tmp.listSync(), isEmpty);
  });

  test('queued downloads capture their settings when each starts', () async {
    final opened = Completer<void>();
    final release = Completer<void>();
    var count = 0;
    final stream = MediaStream(
      container: 'mp4',
      totalBytes: 1,
      open: () async* {
        if (count++ == 0) {
          opened.complete();
          await release.future;
        }
        yield [1];
      },
    );
    var threshold = -50;
    final state = AppState(
      build([stream]),
      opener: (_) async {},
      maxParallel: 1,
      silenceThresholdForDownload: () => threshold,
    );
    final first = state.enqueue(info, DownloadKind.audio);
    await opened.future;
    final second = state.enqueue(info, DownloadKind.audio);
    threshold = -30;
    release.complete();
    await Future.wait([first, second]);
    expect(converter.thresholds, [-50, -30]);
    state.dispose();
  });

  test('falls back to the next client when a stream fails or stalls', () async {
    await build([failing(), stalled(), okStream('webm')])
        .download(info, DownloadKind.video);
    expect(saver.saved, ['video:Song_ Test_1.webm']);
  });

  test('fails with a clear message when every stream is blocked', () {
    expect(
      build([failing()]).download(info, DownloadKind.audio),
      throwsA(isA<DownloadException>()),
    );
    expect(
      build([]).download(info, DownloadKind.audio),
      throwsA(isA<DownloadException>()),
    );
  });
}
