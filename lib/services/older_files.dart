import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'app_settings.dart';
import 'desktop_services.dart';
import 'download_service.dart';

class OlderFile {
  const OlderFile({
    required this.saved,
    required this.name,
    required this.audio,
    this.size,
    this.modified,
  });

  final SavedFile saved;
  final String name;
  final bool audio;
  final int? size;
  final DateTime? modified;
}

abstract class OlderFilesRepository {
  Future<OlderFilesResult> list();
  Future<void> delete(OlderFile file);
}

class OlderFilesResult {
  const OlderFilesResult(this.files, {this.issues = const []});

  final List<OlderFile> files;
  final List<String> issues;
}

class DesktopOlderFilesRepository implements OlderFilesRepository {
  DesktopOlderFilesRepository(this.settings, {String? home})
    : _saver = DesktopFileSaver(settings, home: home);

  final AppSettings settings;
  final DesktopFileSaver _saver;
  final Map<Uri, OlderFile> _listed = {};
  String? _listedFolder;
  int _revision = 0;

  static const _audio = {
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.aac': 'audio/aac',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.oga': 'audio/ogg',
    '.opus': 'audio/opus',
    '.flac': 'audio/flac',
    '.aiff': 'audio/aiff',
    '.wma': 'audio/x-ms-wma',
  };
  static const _video = {
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.mkv': 'video/x-matroska',
    '.mov': 'video/quicktime',
    '.m4v': 'video/x-m4v',
    '.avi': 'video/x-msvideo',
    '.mpeg': 'video/mpeg',
    '.mpg': 'video/mpeg',
    '.3gp': 'video/3gpp',
    '.wmv': 'video/x-ms-wmv',
  };

  @override
  Future<OlderFilesResult> list() async {
    final revision = ++_revision;
    final folder = settings.folderUri;
    final files = <Uri, OlderFile>{};
    final issues = <String>[];
    _listed.clear();
    for (final audio in [true, false]) {
      final directory = _saver.destinationDirectory(audio: audio);
      try {
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is! File) continue;
          final extension = p.extension(entry.path).toLowerCase();
          final mime = _audio[extension] ?? _video[extension];
          if (mime == null) continue;
          final stat = await entry.stat();
          if (stat.type != FileSystemEntityType.file) continue;
          final path = await entry.resolveSymbolicLinks();
          final uri = File(path).uri;
          files[uri] = OlderFile(
            saved: SavedFile(location: entry.path, uri: uri, mime: mime),
            name: p.basename(entry.path),
            audio: mime.startsWith('audio/'),
            size: stat.size,
            modified: stat.modified,
          );
        }
      } on FileSystemException catch (error) {
        issues.add('$error');
      }
    }
    if (revision != _revision || folder != settings.folderUri) {
      throw StateError('Download folder changed while listing files');
    }
    _listedFolder = folder;
    _listed.addAll(files);
    return OlderFilesResult(files.values.toList(), issues: issues);
  }

  @override
  Future<void> delete(OlderFile file) async {
    final revision = _revision;
    final uri = file.saved.uri;
    if (uri == null ||
        _listedFolder != settings.folderUri ||
        !identical(_listed[uri], file)) {
      throw StateError('File is no longer in the current listing');
    }
    final path = uri.toFilePath();
    final location = file.saved.location;
    if (await FileSystemEntity.type(location, followLinks: false) !=
            FileSystemEntityType.file ||
        await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw StateError('File is missing or is no longer a regular file');
    }
    final resolved = p.normalize(await File(location).resolveSymbolicLinks());
    final expected = p.normalize(path);
    if (Platform.isWindows
        ? resolved.toLowerCase() != expected.toLowerCase()
        : resolved != expected) {
      throw StateError('File location changed since the listing was loaded');
    }
    final current = await File(path).stat();
    if (current.size != file.size || current.modified != file.modified) {
      throw StateError('File changed since the listing was loaded');
    }
    if (revision != _revision || _listedFolder != settings.folderUri) {
      throw StateError('File is no longer in the current listing');
    }
    await File(path).delete();
    _listed.remove(uri);
  }
}

class AndroidOlderFilesRepository implements OlderFilesRepository {
  AndroidOlderFilesRepository(this.settings);
  final AppSettings settings;
  static const _channel = MethodChannel(
    'de.maik.youtube_downloader/older_files',
  );
  final Map<Uri, OlderFile> _listed = {};
  String? _listedFolder;
  int _revision = 0;

  @override
  Future<OlderFilesResult> list() async {
    final revision = ++_revision;
    final folder = settings.folderUri;
    _listed.clear();
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'list',
      folder,
    );
    if (result == null) throw StateError('Storage provider returned no result');
    final values = (result['files'] as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final issues = (result['issues'] as List<Object?>).cast<String>();
    if (revision != _revision || folder != settings.folderUri) {
      throw StateError('Download folder changed while listing files');
    }
    final files = [
      for (final value in values)
        OlderFile(
          saved: SavedFile(
            uri: Uri.parse(value['uri'] as String),
            location: value['location'] as String,
            mime: value['mime'] as String,
          ),
          name: value['name'] as String,
          audio: value['audio'] as bool,
          size: value['size'] as int?,
          modified: value['modified'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(value['modified'] as int),
        ),
    ];
    _listedFolder = folder;
    for (final file in files) {
      _listed[file.saved.uri!] = file;
    }
    return OlderFilesResult(_listed.values.toList(), issues: issues);
  }

  @override
  Future<void> delete(OlderFile file) async {
    final uri = file.saved.uri;
    if (uri == null ||
        _listedFolder != settings.folderUri ||
        !identical(_listed[uri], file)) {
      throw StateError('File is no longer in the current listing');
    }
    final deleted = await _channel.invokeMethod<bool>('delete', uri.toString());
    if (deleted != true) throw StateError('Storage provider refused deletion');
    _listed.remove(uri);
  }
}
