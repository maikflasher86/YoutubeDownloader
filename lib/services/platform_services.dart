import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'app_settings.dart';
import 'desktop_services.dart';

/// Converts an audio file (m4a/webm) to mp3.
abstract class AudioConverter {
  Future<void> toMp3(String input, String output);

  /// Combines the video track of [video] with the audio track of [audio]
  /// without re-encoding.
  Future<void> mux(String video, String audio, String output);
}

class FfmpegAudioConverter implements AudioConverter {
  @override
  Future<void> mux(String video, String audio, String output) => _run([
        '-y',
        '-i',
        video,
        '-i',
        audio,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        output,
      ], output, 'Merging video and audio');

  @override
  Future<void> toMp3(String input, String output) => _run([
        '-y',
        '-i',
        input,
        '-vn',
        '-codec:a',
        'libmp3lame',
        '-q:a',
        '2',
        output,
      ], output, 'MP3 conversion');

  Future<void> _run(List<String> args, String output, String what) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code) || !File(output).existsSync()) {
      final logs = await session.getAllLogsAsString();
      final tail = (logs ?? '').split('\n').where((l) => l.trim().isNotEmpty);
      throw Exception(
          '$what failed (code ${code?.getValue()}): ${tail.isEmpty ? '' : tail.last}');
    }
  }
}

/// A file that was saved to public storage.
class SavedFile {
  const SavedFile({required this.location, this.uri, required this.mime});

  /// Human readable location, e.g. "Music/YouTube Downloader/a.mp3".
  final String location;

  /// Content URI used to open the file with the default player.
  final Uri? uri;
  final String mime;
}

/// Opens a saved file with the default Android app for its type.
Future<void> openWithDefaultApp(SavedFile file) async {
  if (isDesktop) return openOnDesktop(file);
  final uri = file.uri;
  if (uri == null) throw Exception('No file to open');
  await AndroidIntent(
    action: 'action_view',
    data: uri.toString(),
    type: file.mime,
    flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION],
  ).launch();
}

/// Moves a finished file into the public storage (Music / Movies).
abstract class FileSaver {
  Future<SavedFile> save(File file, {required bool audio});
}

/// Saves into the folder chosen in the settings (sub folders "Audio" and
/// "Video"). Falls back to [fallback] while no folder is chosen.
class SettingsFileSaver implements FileSaver {
  SettingsFileSaver(this.settings, this.fallback);

  final AppSettings settings;
  final FileSaver fallback;

  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    final tree = settings.folderUri;
    if (tree == null) return fallback.save(file, audio: audio);
    final sub = audio ? 'Audio' : 'Video';
    final dir = await SafUtil().mkdirp(tree, [sub]);
    final name = file.uri.pathSegments.last;
    final mime = mimeFor(name);
    final saved = await SafStream()
        .pasteLocalFile(file.path, dir.uri, name, mime, overwrite: true);
    return SavedFile(
      location: '${settings.folderName ?? 'Folder'}/$sub/$name',
      uri: saved.uri,
      mime: mime,
    );
  }

  static String mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }
}

class MediaStoreFileSaver implements FileSaver {
  static const folder = 'YouTube Downloader';
  bool _ready = false;

  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    if (!_ready) {
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = folder;
      _ready = true;
    }
    final info = await MediaStore().saveFile(
      tempFilePath: file.path,
      dirType: audio ? DirType.audio : DirType.video,
      dirName: audio ? DirName.music : DirName.movies,
    );
    if (info == null) throw Exception('Could not save file');
    return SavedFile(
      location: '${audio ? 'Music' : 'Movies'}/$folder/${info.name}',
      uri: info.uri,
      mime: SettingsFileSaver.mimeFor(info.name),
    );
  }
}
