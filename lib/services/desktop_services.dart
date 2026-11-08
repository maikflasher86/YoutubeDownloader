import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_settings.dart';
import 'platform_services.dart';

/// Runs the ffmpeg executable. It is searched next to the app first, then on
/// the PATH.
class DesktopAudioConverter implements AudioConverter {
  DesktopAudioConverter({this._executable});

  final String? _executable;

  String get _ffmpeg {
    if (_executable != null) return _executable;
    final name = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final local = p.join(p.dirname(Platform.resolvedExecutable), name);
    return File(local).existsSync() ? local : 'ffmpeg';
  }

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

  Future<void> _run(List<String> args, String output, String what) async {
    final ProcessResult res;
    try {
      res = await Process.run(_ffmpeg, args);
    } on ProcessException {
      throw Exception(
          '$what failed: ffmpeg not found. Install ffmpeg or put it next to the app.');
    }
    if (res.exitCode != 0 || !File(output).existsSync()) {
      final tail = '${res.stderr}'
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      throw Exception(
          '$what failed (code ${res.exitCode}): ${tail.isEmpty ? '' : tail.last}');
    }
  }
}

/// Copies finished files into the `Audio` or `Video` sub folder of the chosen
/// folder. Without a choice it uses Music / Videos of the user profile.
class DesktopFileSaver implements FileSaver {
  DesktopFileSaver(this.settings, {String? home})
      : _home = home ?? Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '.';

  final AppSettings settings;
  final String _home;

  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    final base = settings.folderUri ??
        p.join(_home, audio ? 'Music' : 'Videos', 'YouTube Downloader');
    final dir = settings.folderUri == null
        ? Directory(base)
        : Directory(p.join(base, audio ? 'Audio' : 'Video'));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, p.basename(file.path)));
    await file.copy(target.path);
    return SavedFile(
      location: target.path,
      uri: target.uri,
      mime: SettingsFileSaver.mimeFor(target.path),
    );
  }
}

/// True on the platforms that use the desktop services (no share sheet, no SAF).
bool get isDesktop => Platform.isWindows || Platform.isLinux;

/// Opens a file with the default app of the desktop.
Future<void> openOnDesktop(SavedFile file) async {
  final uri = file.uri;
  if (uri == null) throw Exception('No file to open');
  if (Platform.isLinux) {
    await Process.run('xdg-open', [uri.toFilePath()]);
    return;
  }
  // The empty title argument stops "start" from reading the path as a title.
  await Process.run('cmd', ['/c', 'start', '', uri.toFilePath()]);
}
