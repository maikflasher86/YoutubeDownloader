import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/models/download_item.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/youtube_source.dart';

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
  Stream<MediaStream> candidates(String videoId, DownloadKind kind,
          {int? height}) =>
      Stream.fromIterable(streams);

  @override
  void close() {}
}

class FakeConverter implements AudioConverter {
  bool failMux = false;
  final muxed = <String>[];

  @override
  Future<void> toMp3(String input, String output) async {
    File(output).writeAsBytesSync(File(input).readAsBytesSync());
  }

  @override
  Future<void> mux(String video, String audio, String output) async {
    if (failMux) throw Exception('mux failed');
    muxed.add('${video.split(Platform.pathSeparator).last}+${audio.split(Platform.pathSeparator).last}');
    File(output).writeAsBytesSync([1]);
  }
}

class FakeSaver implements FileSaver {
  final saved = <String>[];
  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    saved.add('${audio ? 'audio' : 'video'}:${file.uri.pathSegments.last}');
    return SavedFile(
        location: 'Music/${file.uri.pathSegments.last}', mime: 'audio/mpeg');
  }
}

MediaStream okStream(String container) => MediaStream(
      container: container,
      totalBytes: 6,
      open: () => Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6]
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

  MediaStream videoOnly(int h) => MediaStream(
        container: 'mp4',
        totalBytes: 6,
        videoOnly: true,
        height: h,
        open: () => Stream.value([1, 2, 3, 4, 5, 6]),
      );

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
    final progress = <String>[];
    final path = await build([okStream('mp4')]).download(
      info,
      DownloadKind.audio,
      onProgress: (p, s) => progress.add(s),
    );
    expect(path.location, 'Music/Song_ Test_1.mp3');
    expect(saver.saved, ['audio:Song_ Test_1.mp3']);
    expect(progress, containsAll(['Downloading', 'Converting to MP3']));
    expect(tmp.listSync(), isEmpty);
  });

  test('downloads video without conversion', () async {
    await build([okStream('mp4')]).download(info, DownloadKind.video);
    expect(saver.saved, ['video:Song_ Test_1.mp4']);
  });

  test('falls back to the next client when a stream fails or stalls',
      () async {
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
