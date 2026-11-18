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

  test('older files are disabled by default and the choice persists', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.showOlderFiles, isFalse);
    await settings.setShowOlderFiles(true);
    final restored = AppSettings();
    await restored.load();
    expect(restored.showOlderFiles, isTrue);
    await restored.setShowOlderFiles(false);
    final disabled = AppSettings();
    await disabled.load();
    expect(disabled.showOlderFiles, isFalse);
  });

  test('silence settings default, notify and persist at both limits', () async {
    final settings = AppSettings();
    var notifications = 0;
    settings.addListener(() => notifications++);
    await settings.load();
    expect(settings.trimLeadingSilence, isFalse);
    expect(settings.silenceThresholdDb, -50);
    await settings.setTrimLeadingSilence(true);
    await settings.setSilenceThresholdDb(-80);
    final restored = AppSettings();
    await restored.load();
    expect(restored.trimLeadingSilence, isTrue);
    expect(restored.silenceThresholdDb, -80);
    await restored.setSilenceThresholdDb(-20);
    await restored.setTrimLeadingSilence(false);
    final again = AppSettings();
    await again.load();
    expect(again.trimLeadingSilence, isFalse);
    expect(again.silenceThresholdDb, -20);
    expect(notifications, 3);
  });

  test('invalid stored silence settings are reset and persisted', () async {
    for (final invalid in [-81, -19, 'invalid', 1.5, true]) {
      SharedPreferences.setMockInitialValues({
        'trimLeadingSilence': 'invalid',
        'silenceThresholdDb': invalid,
        'folderName': 'Music',
      });
      final settings = AppSettings();
      await settings.load();
      final prefs = await SharedPreferences.getInstance();
      expect(settings.trimLeadingSilence, isFalse);
      expect(settings.silenceThresholdDb, -50);
      expect(prefs.getBool('trimLeadingSilence'), isFalse);
      expect(prefs.getInt('silenceThresholdDb'), -50);
      expect(settings.folderName, 'Music');
    }
  });

  test(
    'out-of-range thresholds are rejected without changing settings',
    () async {
      final settings = AppSettings();
      await settings.setSilenceThresholdDb(-45);
      for (final invalid in [-81, -19]) {
        await expectLater(
          settings.setSilenceThresholdDb(invalid),
          throwsRangeError,
        );
      }
      expect(settings.silenceThresholdDb, -45);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('silenceThresholdDb'), -45);
    },
  );

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

  testWidgets('settings page enables and disables older files', (t) async {
    final settings = AppSettings();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );
    final toggle = find.byKey(const Key('showOlderFiles'));
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(settings.showOlderFiles, isTrue);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(settings.showOlderFiles, isFalse);
  });

  for (final locale in [const Locale('en'), const Locale('de')]) {
    testWidgets('silence controls work in ${locale.languageCode}', (t) async {
      final settings = AppSettings();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      final toggle = find.byKey(const Key('trimLeadingSilence'));
      final slider = find.byKey(const Key('silenceThresholdDb'));
      await t.ensureVisible(toggle);
      await t.pumpAndSettle();
      expect(find.textContaining('50 ms'), findsOneWidget);
      expect(t.widget<Slider>(slider).onChanged, isNull);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(settings.trimLeadingSilence, isTrue);
      await t.ensureVisible(slider);
      await t.pumpAndSettle();
      expect(t.widget<Slider>(slider).onChanged, isNotNull);
      expect(
        find.text(
          locale.languageCode == 'en'
              ? 'Higher (less-negative) thresholds can remove quiet audio.'
              : 'Höhere (weniger negative) Schwellenwerte können leise Audioinhalte entfernen.',
        ),
        findsOneWidget,
      );
      await t.tapAt(
        t.getTopLeft(slider) +
            Offset(t.getSize(slider).width * .75, t.getSize(slider).height / 2),
      );
      await t.pumpAndSettle();
      expect(settings.silenceThresholdDb, greaterThan(-50));
      final restored = AppSettings();
      await restored.load();
      expect(restored.trimLeadingSilence, isTrue);
      expect(restored.silenceThresholdDb, settings.silenceThresholdDb);
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(settings.trimLeadingSilence, isFalse);
      expect(t.widget<Slider>(slider).onChanged, isNull);
    });
  }

  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets('silence settings fit at ${size.width} width', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
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
      await t.scrollUntilVisible(
        find.byKey(const Key('silenceThresholdDb')),
        200,
        scrollable: find.byType(Scrollable),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('silenceThresholdDb')), findsOneWidget);
    });
  }

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
    await t.ensureVisible(find.byKey(const Key('imprintTile')));
    await t.tap(find.byKey(const Key('imprintTile')));
    await t.pumpAndSettle();
    expect(find.text('Maik Neumann'), findsOneWidget);
    expect(find.textContaining('privat'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });
}
