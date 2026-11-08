import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'app_settings.dart';
import 'download_service.dart';

/// Runs ffmpeg through ffmpeg_kit, because Android has no ffmpeg binary.
class FfmpegKitConverter extends FfmpegConverter {
  @override
  Future<(int?, String)> execute(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final code = (await session.getReturnCode())?.getValue();
    final log = code == 0 ? '' : await session.getAllLogsAsString() ?? '';
    return (code, log);
  }
}

/// Opens a saved file with the default Android app for its type.
Future<void> openOnAndroid(SavedFile file) async {
  final uri = file.uri;
  if (uri == null) throw Exception('No file to open');
  await AndroidIntent(
    action: 'action_view',
    data: uri.toString(),
    type: file.mime,
    flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION],
  ).launch();
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
    final name = p.basename(file.path);
    final mime = mimeFor(name);
    final saved = await SafStream().pasteLocalFile(
      file.path,
      dir.uri,
      name,
      mime,
      overwrite: true,
    );
    return SavedFile(
      location: '${settings.folderName ?? 'Folder'}/$sub/$name',
      uri: saved.uri,
      mime: mime,
    );
  }
}

/// Saves into Music or Movies through the MediaStore.
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
      mime: mimeFor(info.name),
    );
  }
}
