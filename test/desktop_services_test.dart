import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/desktop_services.dart';
import 'package:youtube_downloader/services/download_service.dart';

class RecordingFfmpeg extends FfmpegConverter {
  RecordingFfmpeg(this.code, this.log);
  final int code;
  final String log;
  final commands = <List<String>>[];

  @override
  Future<(int?, String)> execute(List<String> args) async {
    commands.add(args);
    if (args.contains('-y')) File(args.last).writeAsBytesSync([1]);
    return (args.contains('-y') ? 0 : code, log);
  }
}

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
    final saver = DesktopFileSaver(
      AppSettings(),
      home: p.join(tmp.path, 'home'),
    );
    final src = File(p.join(tmp.path, 'a.mp3'))..writeAsBytesSync([1, 2]);
    final saved = await saver.save(src, audio: true);
    expect(
      saved.location,
      p.join(tmp.path, 'home', 'Music', 'YouTube Downloader', 'a.mp3'),
    );
    expect(File(saved.location).existsSync(), isTrue);
    expect(saved.mime, 'audio/mpeg');

    final v = File(p.join(tmp.path, 'b.mp4'))..writeAsBytesSync([1]);
    final savedV = await saver.save(v, audio: false);
    expect(
      savedV.location,
      p.join(tmp.path, 'home', 'Videos', 'YouTube Downloader', 'b.mp4'),
    );
  });

  test('saver uses Audio and Video sub folders of the chosen folder', () async {
    final settings = AppSettings();
    await settings.setFolder(p.join(tmp.path, 'chosen'), 'chosen');
    final saver = DesktopFileSaver(settings, home: tmp.path);
    final a = await saver.save(
      File(p.join(tmp.path, 'x.mp3'))..writeAsBytesSync([1]),
      audio: true,
    );
    final v = await saver.save(
      File(p.join(tmp.path, 'y.mp4'))..writeAsBytesSync([1]),
      audio: false,
    );
    expect(a.location, p.join(tmp.path, 'chosen', 'Audio', 'x.mp3'));
    expect(v.location, p.join(tmp.path, 'chosen', 'Video', 'y.mp4'));
  });

  test('converter reports a missing ffmpeg', () {
    final c = DesktopAudioConverter(executable: 'definitely-not-ffmpeg');
    expect(
      c.toMp3('a', p.join(tmp.path, 'a.mp3')),
      throwsA(predicate((e) => '$e'.contains('ffmpeg not found'))),
    );
  });

  test(
    'disabled trimming leaves conversion and mux commands unchanged',
    () async {
      final converter = RecordingFfmpeg(1, 'unused');
      await converter.toMp3('in', p.join(tmp.path, 'out.mp3'));
      await converter.mux('video', 'audio', p.join(tmp.path, 'out.mp4'));
      expect(converter.commands[0], [
        '-y',
        '-i',
        'in',
        '-vn',
        '-codec:a',
        'libmp3lame',
        '-q:a',
        '2',
        p.join(tmp.path, 'out.mp3'),
      ]);
      expect(converter.commands[1], [
        '-y',
        '-i',
        'video',
        '-i',
        'audio',
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        p.join(tmp.path, 'out.mp4'),
      ]);
    },
  );

  test(
    'detection errors and invalid thresholds do not run conversion',
    () async {
      final converter = RecordingFfmpeg(1, 'filter unavailable');
      await expectLater(
        converter.toMp3(
          'in',
          p.join(tmp.path, 'out.mp3'),
          silenceThresholdDb: -50,
        ),
        throwsA(predicate((e) => '$e'.contains('filter unavailable'))),
      );
      expect(converter.commands, hasLength(1));
      await expectLater(
        converter.toMp3(
          'in',
          p.join(tmp.path, 'out.mp3'),
          silenceThresholdDb: -5,
        ),
        throwsA(isA<RangeError>()),
      );
      expect(converter.commands, hasLength(1));
    },
  );

  test(
    'trims leading silence and preserves later audio with real ffmpeg',
    () async {
      String source(String name, String expression, double duration) {
        final path = p.join(tmp.path, '$name.wav');
        final result = Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-y',
          '-f',
          'lavfi',
          '-i',
          'aevalsrc=$expression:s=44100:d=$duration',
          path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return path;
      }

      double duration(String path) {
        final result = Process.runSync('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return double.parse('${result.stdout}'.trim());
      }

      String silence(String path) {
        final result = Process.runSync('ffmpeg', [
          '-hide_banner',
          '-nostats',
          '-i',
          path,
          '-af',
          'silencedetect=n=-50dB:d=0.01,ametadata=mode=print',
          '-f',
          'null',
          '-',
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return '${result.stderr}';
      }

      final c = DesktopAudioConverter();
      final leading = source(
        'leading',
        r'if(between(t\,1\,2)+between(t\,2.5\,3)\,0.2*sin(2*PI*440*t)\,0)',
        3.5,
      );
      final output = p.join(tmp.path, 'leading.mp3');
      await c.toMp3(leading, output, silenceThresholdDb: -50);
      expect(duration(output), closeTo(2.55, 0.08));
      final events = RegExp(r'lavfi\.silence_end=([\d.]+)')
          .allMatches(silence(output))
          .map((m) => double.parse(m.group(1)!))
          .toList();
      expect(events, hasLength(2));
      expect(events[0], closeTo(0.05, 0.02));
      expect(events[1], closeTo(1.55, 0.03));

      final normal = source('normal', '0.2*sin(2*PI*440*t)', 1);
      final normalOut = p.join(tmp.path, 'normal.mp3');
      await c.toMp3(normal, normalOut, silenceThresholdDb: -50);
      expect(duration(normalOut), closeTo(1, 0.06));

      final silent = source('silent', '0', 1);
      final silentOut = p.join(tmp.path, 'silent.mp3');
      await c.toMp3(silent, silentOut, silenceThresholdDb: -50);
      expect(duration(silentOut), closeTo(1, 0.06));

      final short = source(
        'short',
        r'if(gte(t\,0.1)\,0.2*sin(2*PI*440*t)\,0)',
        0.12,
      );
      final shortOut = p.join(tmp.path, 'short.mp3');
      await c.toMp3(short, shortOut, silenceThresholdDb: -50);
      expect(duration(shortOut), closeTo(0.07, 0.06));

      final stereo = source(
        'stereo',
        r'if(gte(t\,0.2)\,0.2*sin(2*PI*440*t)\,0)|if(gte(t\,1)\,0.2*sin(2*PI*440*t)\,0)',
        2,
      );
      final stereoOut = p.join(tmp.path, 'stereo.mp3');
      await c.toMp3(stereo, stereoOut, silenceThresholdDb: -50);
      expect(duration(stereoOut), closeTo(1.85, 0.08));

      final quiet = source(
        'quiet',
        r'if(lt(t\,0.5)\,0.001*sin(2*PI*440*t)\,0.2*sin(2*PI*440*t))',
        1,
      );
      final quietOut = p.join(tmp.path, 'quiet.mp3');
      await c.toMp3(quiet, quietOut, silenceThresholdDb: -50);
      expect(duration(quietOut), closeTo(0.55, 0.08));
    },
    skip: _hasFfmpeg ? false : 'ffmpeg not installed',
  );

  test('converter makes an mp3 and merges tracks with real ffmpeg', () async {
    final audio = p.join(tmp.path, 'in.m4a');
    final video = p.join(tmp.path, 'in.mp4');
    Process.runSync('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:a',
      'aac',
      audio, //
    ]);
    Process.runSync('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=64x64:d=1',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      video, //
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
