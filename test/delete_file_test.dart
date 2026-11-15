import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_downloader/services/delete_file.dart';
import 'package:youtube_downloader/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop deletes only the selected temporary file', () async {
    final dir = await Directory.systemTemp.createTemp('delete_file_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}test.mp3');
    await file.writeAsString('fixture');
    final saved = SavedFile(
      location: file.path,
      uri: file.uri,
      mime: 'audio/mpeg',
    );
    await deleteOnDesktop(saved);
    expect(await file.exists(), isFalse);
    await expectLater(
      deleteOnDesktop(saved),
      throwsA(
        isA<DeleteFailure>().having(
          (e) => e.kind,
          'kind',
          DeleteFailureKind.missing,
        ),
      ),
    );
  });

  test('Android sends the content URI and reports provider refusal', () async {
    const channel = MethodChannel('de.maik.youtube_downloader/delete_file');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    var allowed = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return allowed;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final saved = SavedFile(
      location: 'Music/file',
      uri: Uri.parse('content://provider/document/1'),
      mime: 'audio/mpeg',
    );
    await deleteOnAndroid(saved);
    expect(calls.single.arguments, 'content://provider/document/1');
    allowed = false;
    await expectLater(
      deleteOnAndroid(saved),
      throwsA(
        isA<DeleteFailure>().having(
          (e) => e.kind,
          'kind',
          DeleteFailureKind.missingOrDenied,
        ),
      ),
    );
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'permission_denied',
        message: 'Access denied',
      );
    });
    await expectLater(
      deleteOnAndroid(saved),
      throwsA(isA<PlatformException>()),
    );
  });
}
