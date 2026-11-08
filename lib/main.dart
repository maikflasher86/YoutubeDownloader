import 'package:media_kit/media_kit.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'services/android_services.dart';
import 'services/app_settings.dart';
import 'services/desktop_services.dart';
import 'services/download_service.dart';
import 'services/shared_text.dart';
import 'services/youtube_source.dart';
import 'ui/app_state.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final tmp = await getTemporaryDirectory();
  final settings = AppSettings();
  await settings.load();
  final service = DownloadService(
    source: ExplodeYoutubeSource(),
    converter: isDesktop ? DesktopAudioConverter() : FfmpegKitConverter(),
    saver: isDesktop
        ? DesktopFileSaver(settings)
        : SettingsFileSaver(settings, MediaStoreFileSaver()),
    tempDir: Directory(p.join(tmp.path, 'downloads')),
  );
  runApp(
    YoutubeDownloaderApp(
      state: AppState(
        service,
        opener: isDesktop ? openOnDesktop : openOnAndroid,
      ),
      settings: settings,
      sharedText: isDesktop ? NoSharedTextSource() : PluginSharedTextSource(),
    ),
  );
}

class YoutubeDownloaderApp extends StatefulWidget {
  const YoutubeDownloaderApp({
    super.key,
    required this.state,
    required this.settings,
    required this.sharedText,
  });

  final AppState state;
  final AppSettings settings;
  final SharedTextSource sharedText;

  @override
  State<YoutubeDownloaderApp> createState() => _YoutubeDownloaderAppState();
}

class _YoutubeDownloaderAppState extends State<YoutubeDownloaderApp> {
  final _home = GlobalKey<HomePageState>();
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    widget.sharedText.initial().then(_onShared);
    _sub = widget.sharedText.stream.listen(_onShared);
  }

  void _onShared(String? text) {
    if (text == null) return;
    // Wait for the first frame so HomePage exists.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _home.currentState?.openLink(text),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.state),
        ChangeNotifierProvider.value(value: widget.settings),
      ],
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        home: HomePage(key: _home),
      ),
    );
  }
}
