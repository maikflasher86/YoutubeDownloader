import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_settings.dart';
import 'download_service.dart';

/// True on the platforms that use the desktop services (no share sheet, no SAF).
bool get isDesktop => Platform.isWindows || Platform.isLinux;

/// Runs the ffmpeg executable. It is searched next to the app first, then on
/// the PATH.
class DesktopAudioConverter extends FfmpegConverter {
  DesktopAudioConverter({this.executable});

  final String? executable;

  String get _ffmpeg {
    if (executable != null) return executable!;
    final name = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final local = p.join(p.dirname(Platform.resolvedExecutable), name);
    return File(local).existsSync() ? local : 'ffmpeg';
  }

  @override
  Future<(int?, String)> execute(List<String> args) async {
    try {
      final res = await Process.run(_ffmpeg, args);
      return (res.exitCode, '${res.stderr}');
    } on ProcessException {
      throw Exception(
          'ffmpeg not found. Install ffmpeg or put it next to the app.');
    }
  }
}

/// Copies finished files into the `Audio` or `Video` sub folder of the chosen
/// folder. Without a choice it uses Music / Videos of the user profile.
class DesktopFileSaver implements FileSaver {
  DesktopFileSaver(this.settings, {String? home})
      : _home = home ??
            Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ??
            '.';

  final AppSettings settings;
  final String _home;

  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    final chosen = settings.folderUri;
    final dir = Directory(chosen == null
        ? p.join(_home, audio ? 'Music' : 'Videos', 'YouTube Downloader')
        : p.join(chosen, audio ? 'Audio' : 'Video'));
    await dir.create(recursive: true);
    final target = await file.copy(p.join(dir.path, p.basename(file.path)));
    return SavedFile(
      location: target.path,
      uri: target.uri,
      mime: mimeFor(target.path),
    );
  }
}

/// Opens a file with the default app of the desktop.
Future<void> openOnDesktop(SavedFile file) async {
  final uri = file.uri;
  if (uri == null) throw Exception('No file to open');
  final path = uri.toFilePath();
  if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  } else {
    // The empty title argument stops "start" from reading the path as a title.
    await Process.run('cmd', ['/c', 'start', '', path]);
  }
}
