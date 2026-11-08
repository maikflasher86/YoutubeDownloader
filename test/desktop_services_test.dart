import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/desktop_services.dart';

bool get _hasFfmpeg {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('yt_desktop');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('saver copies into Music and Videos defaults', () async {
    final saver = DesktopFileSaver(AppSettings(), home: p.join(tmp.path, 'home'));
    final src = File(p.join(tmp.path, 'a.mp3'))..writeAsBytesSync([1, 2]);
    final saved = await saver.save(src, audio: true);
    expect(saved.location,
        p.join(tmp.path, 'home', 'Music', 'YouTube Downloader', 'a.mp3'));
    expect(File(saved.location).existsSync(), isTrue);
    expect(saved.mime, 'audio/mpeg');

    final v = File(p.join(tmp.path, 'b.mp4'))..writeAsBytesSync([1]);
    final savedV = await saver.save(v, audio: false);
    expect(savedV.location,
        p.join(tmp.path, 'home', 'Videos', 'YouTube Downloader', 'b.mp4'));
  });

  test('saver uses Audio and Video sub folders of the chosen folder',
      () async {
    final settings = AppSettings();
    await settings.setFolder(p.join(tmp.path, 'chosen'), 'chosen');
    final saver = DesktopFileSaver(settings, home: tmp.path);
    final a = await saver.save(
        File(p.join(tmp.path, 'x.mp3'))..writeAsBytesSync([1]),
        audio: true);
    final v = await saver.save(
        File(p.join(tmp.path, 'y.mp4'))..writeAsBytesSync([1]),
        audio: false);
    expect(a.location, p.join(tmp.path, 'chosen', 'Audio', 'x.mp3'));
    expect(v.location, p.join(tmp.path, 'chosen', 'Video', 'y.mp4'));
  });

  test('converter reports a missing ffmpeg', () {
    final c = DesktopAudioConverter(executable: 'definitely-not-ffmpeg');
    expect(c.toMp3('a', p.join(tmp.path, 'a.mp3')),
        throwsA(predicate((e) => '$e'.contains('ffmpeg not found'))));
  });

  test('converter makes an mp3 and merges tracks with real ffmpeg', () async {
    final audio = p.join(tmp.path, 'in.m4a');
    final video = p.join(tmp.path, 'in.mp4');
    Process.runSync('ffmpeg', [
      '-y', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1', '-c:a', 'aac', audio, //
    ]);
    Process.runSync('ffmpeg', [
      '-y', '-f', 'lavfi', '-i', 'color=c=red:s=64x64:d=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video, //
    ]);
    final c = DesktopAudioConverter();
    final mp3 = p.join(tmp.path, 'out.mp3');
    await c.toMp3(audio, mp3);
    expect(File(mp3).lengthSync(), greaterThan(0));

    final merged = p.join(tmp.path, 'merged.mp4');
    await c.mux(video, audio, merged);
    final probe = Process.runSync('ffmpeg', ['-i', merged]);
    expect('${probe.stderr}', allOf(contains('Video:'), contains('Audio:')));
  }, skip: _hasFfmpeg ? false : 'ffmpeg not installed');
}
