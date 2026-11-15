import 'dart:io';

import 'package:flutter/services.dart';

import 'download_service.dart';

enum DeleteFailureKind {
  missing,
  missingOrDenied,
  unavailable,
  busy,
  persistence,
}

class DeleteFailure implements Exception {
  const DeleteFailure(this.kind, [this.details]);
  final DeleteFailureKind kind;
  final String? details;
}

Future<void> deleteOnDesktop(SavedFile saved) async {
  final uri = saved.uri;
  if (uri == null || uri.scheme != 'file') {
    throw const DeleteFailure(DeleteFailureKind.unavailable);
  }
  final path = uri.toFilePath();
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    throw const DeleteFailure(DeleteFailureKind.missing);
  }
  if (type != FileSystemEntityType.file) {
    throw const DeleteFailure(DeleteFailureKind.unavailable);
  }
  await File(path).delete();
}

const _channel = MethodChannel('de.maik.youtube_downloader/delete_file');

Future<void> deleteOnAndroid(SavedFile saved) async {
  final uri = saved.uri;
  if (uri == null || uri.scheme != 'content') {
    throw const DeleteFailure(DeleteFailureKind.unavailable);
  }
  final deleted = await _channel.invokeMethod<bool>('delete', uri.toString());
  if (deleted != true) {
    throw const DeleteFailure(DeleteFailureKind.missingOrDenied);
  }
}
