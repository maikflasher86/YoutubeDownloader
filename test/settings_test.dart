import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_downloader/l10n/app_localizations.dart';
import 'package:youtube_downloader/models/video_quality.dart';
import 'package:youtube_downloader/services/app_settings.dart';
import 'package:youtube_downloader/services/download_service.dart';
import 'package:youtube_downloader/services/android_services.dart';
import 'package:youtube_downloader/ui/settings_page.dart';

class _FakeSaver implements FileSaver {
  bool called = false;
  @override
  Future<SavedFile> save(File file, {required bool audio}) async {
    called = true;
    return const SavedFile(location: 'default', mime: 'audio/mpeg');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('settings persist the chosen folder', () async {
    final s = AppSettings();
    await s.setFolder('content://tree/x', 'Music');
    final again = AppSettings();
    await again.load();
    expect(again.folderUri, 'content://tree/x');
    expect(again.folderName, 'Music');
    await again.resetFolder();
    expect(again.folderUri, isNull);
  });

  test('saver uses the default location without a chosen folder', () async {
    final fallback = _FakeSaver();
    final saver = SettingsFileSaver(AppSettings(), fallback);
    expect((await saver.save(File('a.mp3'), audio: true)).location, 'default');
    expect(fallback.called, isTrue);
  });

  test('mime type follows the file extension', () {
    expect(mimeFor('a.mp3'), 'audio/mpeg');
    expect(mimeFor('a.mp4'), 'video/mp4');
    expect(mimeFor('a.webm'), 'video/webm');
  });

  testWidgets('settings page stores and resets the picked folder', (t) async {
    final settings = AppSettings();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(
            pickFolder: () async => ('content://tree/m', 'Music'),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('folderTile')));
    await t.pumpAndSettle();
    expect(settings.folderName, 'Music');
    expect(find.textContaining('Music'), findsWidgets);

    await t.tap(find.byKey(const Key('resetFolder')));
    await t.pumpAndSettle();
    expect(settings.folderUri, isNull);
  });

  test('default video quality is 1080p and is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    expect(s.videoQuality, VideoQuality.resolution1080p);
    await s.setVideoQuality(VideoQuality.resolution1080p);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('videoQuality'), 'resolution1080p');
    final again = AppSettings();
    await again.load();
    expect(again.videoQuality, VideoQuality.resolution1080p);
  });

  test('unknown stored video quality uses the default', () async {
    SharedPreferences.setMockInitialValues({'videoQuality': 'unknownQuality'});
    final settings = AppSettings();
    await settings.load();
    expect(settings.videoQuality, VideoQuality.defaultQuality);
    expect(VideoQuality.fromName(null), VideoQuality.defaultQuality);
  });

  testWidgets('imprint shows developer, private-use notice and version', (
    t,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'youtube_downloader',
      packageName: 'x',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppSettings(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('imprintTile')));
    await t.pumpAndSettle();
    expect(find.text('Maik Neumann'), findsOneWidget);
    expect(find.textContaining('privat'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });
}
