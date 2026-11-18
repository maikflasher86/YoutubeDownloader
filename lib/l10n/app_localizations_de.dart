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
  String get loadVideo => 'Video abrufen';

  @override
  String get linkTitle => 'Link einfügen';

  @override
  String get downloads => 'Downloads';

  @override
  String get searchTitle => 'YouTube durchsuchen';

  @override
  String get searchHint => 'Nach Videos suchen';

  @override
  String get searchEmpty => 'Keine Ergebnisse';

  @override
  String errorSearch(String details) {
    return 'Suche fehlgeschlagen: $details';
  }

  @override
  String get addedToQueue => 'Zur Warteschlange hinzugefügt';

  @override
  String get search => 'Suchen';

  @override
  String get batchDownload => 'Batch-Download';

  @override
  String get batchHint => 'Ein YouTube-Link pro Zeile';

  @override
  String get batchStart => 'Download starten';

  @override
  String get batchNoLinks => 'Keine gültigen YouTube-Links gefunden';

  @override
  String batchStarted(int count) {
    return '$count Links in der Warteschlange';
  }

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
  String get showOlderFiles => 'Ältere Dateien anzeigen';

  @override
  String get showOlderFilesDescription =>
      'Zeigt Audio- und Videodateien in den Downloadordnern an. Die Ordner können Dateien anderer Apps enthalten.';

  @override
  String get trimLeadingSilence =>
      'Stille am Anfang von MP3-Downloads entfernen';

  @override
  String get trimLeadingSilenceDescription =>
      'Vor Beginn des Audios bleiben fest 50 ms erhalten.';

  @override
  String get silenceThreshold => 'Stille-Schwellenwert';

  @override
  String get silenceThresholdWarning =>
      'Höhere (weniger negative) Schwellenwerte können leise Audioinhalte entfernen.';

  @override
  String settingSaveFailed(String details) {
    return 'Die App konnte die Einstellung nicht speichern: $details';
  }

  @override
  String get olderFiles => 'Ältere Dateien';

  @override
  String get olderFilesDescription =>
      'Audio- und Videodateien in den Downloadordnern. Diese können Dateien anderer Apps enthalten.';

  @override
  String get searchFiles => 'Dateien suchen';

  @override
  String get allFiles => 'Alle';

  @override
  String get audio => 'Audio';

  @override
  String get refreshFiles => 'Dateien aktualisieren';

  @override
  String get olderFilesEmpty =>
      'Keine Dateien in den Downloadordnern gefunden.';

  @override
  String get olderFilesNoMatch =>
      'Keine Dateien entsprechen der Suche oder dem Filter.';

  @override
  String olderFilesError(String details) {
    return 'Die App konnte die Downloadordner nicht lesen: $details';
  }

  @override
  String get openFile => 'Datei öffnen';

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
  String get deleteFile => 'Datei löschen';

  @override
  String get deleteConfirmTitle => 'Datei endgültig löschen?';

  @override
  String deleteConfirmBody(String name) {
    return 'Die App löscht diese Datei endgültig: $name';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteMissing =>
      'Die Datei existiert nicht mehr. Der Download bleibt in der Liste.';

  @override
  String get deleteMissingOrDenied =>
      'Die Datei fehlt oder der Speicheranbieter hat das Löschen abgelehnt. Der Download bleibt in der Liste.';

  @override
  String get deleteUnavailable =>
      'Die App kann die Datei an diesem Speicherort nicht löschen.';

  @override
  String get deleteBusy =>
      'Warte, bis alle Downloads abgeschlossen sind, bevor du eine Datei löschst.';

  @override
  String deleteFailed(String details) {
    return 'Die App konnte die Datei nicht löschen: $details';
  }

  @override
  String deletePersistenceFailed(String details) {
    return 'Die Datei wurde gelöscht, aber die App konnte die Download-Markierung nicht aktualisieren: $details';
  }

  @override
  String get stageQueued => 'In der Warteschlange';

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
