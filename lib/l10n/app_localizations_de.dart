// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Youtube Downloader & MP3';

  @override
  String get settings => 'Einstellungen';

  @override
  String get pasteHint => 'YouTube-Link einfügen';

  @override
  String get loadVideo => 'Video laden';

  @override
  String get downloads => 'Downloads';

  @override
  String get videoQuality => 'Videoqualität';

  @override
  String get defaultVideoQuality => 'Standard-Videoqualität';

  @override
  String get mp3 => 'MP3';

  @override
  String get video => 'Video';

  @override
  String get downloadFolder => 'Download-Ordner';

  @override
  String get defaultFolders => 'Standard (Musik und Filme)';

  @override
  String folderSubtitle(String name) {
    return '$name\nAudio → „Audio“, Video → „Video“';
  }

  @override
  String get useDefaultFolders => 'Standardordner verwenden';

  @override
  String get imprint => 'Impressum';

  @override
  String get developer => 'Entwickler';

  @override
  String get usage => 'Nutzung';

  @override
  String get usageText =>
      'Die App darf nur für private Zwecke verwendet werden.';

  @override
  String get version => 'Version';

  @override
  String get failed => 'Fehlgeschlagen';

  @override
  String savedTo(String path) {
    return 'Gespeichert in $path';
  }

  @override
  String get errorInvalidLink => 'Kein gültiger YouTube-Link gefunden';

  @override
  String errorLoad(String details) {
    return 'Video konnte nicht geladen werden: $details';
  }

  @override
  String errorOpen(String details) {
    return 'Datei konnte nicht geöffnet werden: $details';
  }

  @override
  String get stageStarting => 'Startet';

  @override
  String get stageDownloading => 'Lädt herunter';

  @override
  String get stageDownloadingVideo => 'Video wird heruntergeladen';

  @override
  String get stageDownloadingAudio => 'Audio wird heruntergeladen';

  @override
  String get stageConverting => 'Konvertiere zu MP3';

  @override
  String get stageMerging => 'Video und Audio werden zusammengeführt';

  @override
  String get stageSaving => 'Speichert';

  @override
  String get stageSaved => 'Gespeichert';
}
