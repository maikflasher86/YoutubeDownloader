// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Youtube Downloader & MP3';

  @override
  String get settings => 'Settings';

  @override
  String get pasteHint => 'Paste a YouTube link';

  @override
  String get loadVideo => 'Fetch video';

  @override
  String get linkTitle => 'Paste link';

  @override
  String get downloads => 'Downloads';

  @override
  String get searchTitle => 'Search YouTube';

  @override
  String get searchHint => 'Search for videos';

  @override
  String get searchEmpty => 'No results';

  @override
  String errorSearch(String details) {
    return 'Search failed: $details';
  }

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get search => 'Search';

  @override
  String get batchDownload => 'Batch download';

  @override
  String get batchHint => 'One YouTube link per line';

  @override
  String get batchStart => 'Start download';

  @override
  String get batchNoLinks => 'No valid YouTube links found';

  @override
  String batchStarted(int count) {
    return '$count links queued';
  }

  @override
  String get videoQuality => 'Video quality';

  @override
  String get defaultVideoQuality => 'Default video quality';

  @override
  String get mp3 => 'MP3';

  @override
  String get video => 'Video';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get defaultFolders => 'Default (Music and Movies)';

  @override
  String folderSubtitle(String name) {
    return '$name\nAudio → \"Audio\", video → \"Video\"';
  }

  @override
  String get useDefaultFolders => 'Use default folders';

  @override
  String get imprint => 'Imprint';

  @override
  String get developer => 'Developer';

  @override
  String get usage => 'Usage';

  @override
  String get usageText => 'The app may only be used for private purposes.';

  @override
  String get version => 'Version';

  @override
  String get failed => 'Failed';

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get errorInvalidLink => 'No valid YouTube link found';

  @override
  String errorLoad(String details) {
    return 'Could not load video: $details';
  }

  @override
  String errorOpen(String details) {
    return 'Could not open file: $details';
  }

  @override
  String get stageQueued => 'Queued';

  @override
  String get stageStarting => 'Starting';

  @override
  String get stageDownloading => 'Downloading';

  @override
  String get stageDownloadingVideo => 'Downloading video';

  @override
  String get stageDownloadingAudio => 'Downloading audio';

  @override
  String get stageConverting => 'Converting to MP3';

  @override
  String get stageMerging => 'Merging video and audio';

  @override
  String get stageSaving => 'Saving';

  @override
  String get stageSaved => 'Saved';
}
