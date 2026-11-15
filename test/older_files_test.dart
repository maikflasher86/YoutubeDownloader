import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/older_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppSettings settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('older_files_test');
    settings = AppSettings();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('desktop lists only supported files in saver destinations', () async {
    final music = Directory(p.join(root.path, 'Music', 'YouTube Downloader'))
      ..createSync(recursive: true);
    final videos = Directory(p.join(root.path, 'Videos', 'YouTube Downloader'))
      ..createSync(recursive: true);
    File(p.join(music.path, 'song.mp3')).writeAsStringSync('audio');
    File(p.join(music.path, 'notes.txt')).writeAsStringSync('text');
    File(p.join(videos.path, 'movie.mp4')).writeAsStringSync('video');
    File(p.join(videos.path, 'other.mp3')).writeAsStringSync('audio');
    final nested = Directory(p.join(videos.path, 'nested'))..createSync();
    File(p.join(nested.path, 'other.mp4')).writeAsStringSync('nested');
    final repository = DesktopOlderFilesRepository(settings, home: root.path);
    final files = (await repository.list()).files;
    expect(files.map((file) => file.name).toSet(), {
      'song.mp3',
      'movie.mp4',
      'other.mp3',
    });
    final song = files.singleWhere((file) => file.name == 'song.mp3');
    await repository.delete(song);
    expect(File(song.saved.location).existsSync(), isFalse);
    expect(File(p.join(videos.path, 'movie.mp4')).existsSync(), isTrue);
    await expectLater(repository.delete(song), throwsStateError);
  });

  test('desktop reports missing folders and changed files', () async {
    final repository = DesktopOlderFilesRepository(settings, home: root.path);
    final missing = await repository.list();
    expect(missing.files, isEmpty);
    expect(missing.issues, hasLength(2));
    await settings.setFolder(root.path, 'test');
    final audio = Directory(p.join(root.path, 'Audio'))..createSync();
    final file = File(p.join(audio.path, 'song.mp3'))..writeAsStringSync('a');
    final partial = await repository.list();
    expect(partial.issues, hasLength(1));
    final listed = partial.files.single;
    file.writeAsStringSync('changed');
    await expectLater(repository.delete(listed), throwsStateError);
    expect(file.readAsStringSync(), 'changed');
    await settings.resetFolder();
    await expectLater(repository.delete(listed), throwsStateError);
  });

  test(
    'Android preserves provider errors and refuses stale selections',
    () async {
      const channel = MethodChannel('de.maik.youtube_downloader/older_files');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var deletionAllowed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'delete') return deletionAllowed;
        return {
          'files': [
            {
              'uri': 'content://media/external_primary/audio/media/1',
              'name': 'song.mp3',
              'location': 'Music/YouTube Downloader/song.mp3',
              'mime': 'audio/mpeg',
              'audio': true,
              'size': 1,
              'modified': 1000,
            },
          ],
          'issues': <String>['Video folder missing'],
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final repository = AndroidOlderFilesRepository(settings);
      final result = await repository.list();
      expect(result.issues, ['Video folder missing']);
      final file = result.files.single;
      await expectLater(repository.delete(file), throwsStateError);
      deletionAllowed = true;
      await repository.delete(file);
      await expectLater(repository.delete(file), throwsStateError);
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'permission_denied', message: 'denied');
      });
      await expectLater(repository.list(), throwsA(isA<PlatformException>()));
    },
  );

  test('Android ignores a stale listing after a newer refresh', () async {
    const channel = MethodChannel('de.maik.youtube_downloader/older_files');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final first = Completer<Object?>();
    var calls = 0;
    Map<String, Object> file(String name) => {
      'uri': 'content://provider/$name',
      'name': name,
      'location': 'Audio/$name',
      'mime': 'audio/mpeg',
      'audio': true,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'delete') return true;
      calls++;
      if (calls == 1) return first.future;
      return {
        'files': [file('new.mp3')],
        'issues': <String>[],
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final repository = AndroidOlderFilesRepository(settings);
    final stale = repository.list();
    final current = await repository.list();
    first.complete({
      'files': [file('old.mp3')],
      'issues': <String>[],
    });
    await expectLater(stale, throwsStateError);
    expect(current.files.single.name, 'new.mp3');
    await repository.delete(current.files.single);
  });

  test('Android surfaces permission and consent outcomes', () async {
    const channel = MethodChannel('de.maik.youtube_downloader/older_files');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var denied = true;
    Object? deleteOutcome = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'list') {
        if (denied) throw PlatformException(code: 'permission_denied');
        return {
          'files': [
            {
              'uri': 'content://media/external_primary/audio/media/9',
              'name': 'shared.mp3',
              'location': 'Music/YouTube Downloader/shared.mp3',
              'mime': 'audio/mpeg',
              'audio': true,
            },
          ],
          'issues': <String>[],
        };
      }
      if (deleteOutcome is PlatformException) throw deleteOutcome;
      return deleteOutcome;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final repository = AndroidOlderFilesRepository(settings);
    await expectLater(repository.list(), throwsA(isA<PlatformException>()));
    denied = false;
    final file = (await repository.list()).files.single;
    await expectLater(repository.delete(file), throwsStateError);
    deleteOutcome = PlatformException(code: 'provider_error');
    await expectLater(
      repository.delete(file),
      throwsA(isA<PlatformException>()),
    );
    deleteOutcome = true;
    await repository.delete(file);
    await expectLater(repository.delete(file), throwsStateError);
  });
}
