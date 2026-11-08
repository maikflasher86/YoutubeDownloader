import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Youtube Downloader & MP3'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube link'**
  String get pasteHint;

  /// No description provided for @loadVideo.
  ///
  /// In en, this message translates to:
  /// **'Fetch video'**
  String get loadVideo;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste link'**
  String get linkTitle;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for videos'**
  String get searchHint;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchEmpty;

  /// No description provided for @errorSearch.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {details}'**
  String errorSearch(String details);

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get addedToQueue;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @batchDownload.
  ///
  /// In en, this message translates to:
  /// **'Batch download'**
  String get batchDownload;

  /// No description provided for @batchHint.
  ///
  /// In en, this message translates to:
  /// **'One YouTube link per line'**
  String get batchHint;

  /// No description provided for @batchStart.
  ///
  /// In en, this message translates to:
  /// **'Start download'**
  String get batchStart;

  /// No description provided for @batchNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No valid YouTube links found'**
  String get batchNoLinks;

  /// No description provided for @batchStarted.
  ///
  /// In en, this message translates to:
  /// **'{count} links queued'**
  String batchStarted(int count);

  /// No description provided for @videoQuality.
  ///
  /// In en, this message translates to:
  /// **'Video quality'**
  String get videoQuality;

  /// No description provided for @defaultVideoQuality.
  ///
  /// In en, this message translates to:
  /// **'Default video quality'**
  String get defaultVideoQuality;

  /// No description provided for @mp3.
  ///
  /// In en, this message translates to:
  /// **'MP3'**
  String get mp3;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @defaultFolders.
  ///
  /// In en, this message translates to:
  /// **'Default (Music and Movies)'**
  String get defaultFolders;

  /// No description provided for @folderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\nAudio → \"Audio\", video → \"Video\"'**
  String folderSubtitle(String name);

  /// No description provided for @useDefaultFolders.
  ///
  /// In en, this message translates to:
  /// **'Use default folders'**
  String get useDefaultFolders;

  /// No description provided for @imprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint'**
  String get imprint;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @usage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// No description provided for @usageText.
  ///
  /// In en, this message translates to:
  /// **'The app may only be used for private purposes.'**
  String get usageText;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @errorInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'No valid YouTube link found'**
  String get errorInvalidLink;

  /// No description provided for @errorLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load video: {details}'**
  String errorLoad(String details);

  /// No description provided for @errorOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open file: {details}'**
  String errorOpen(String details);

  /// No description provided for @stageQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get stageQueued;

  /// No description provided for @stageStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get stageStarting;

  /// No description provided for @stageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get stageDownloading;

  /// No description provided for @stageDownloadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloading video'**
  String get stageDownloadingVideo;

  /// No description provided for @stageDownloadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Downloading audio'**
  String get stageDownloadingAudio;

  /// No description provided for @stageConverting.
  ///
  /// In en, this message translates to:
  /// **'Converting to MP3'**
  String get stageConverting;

  /// No description provided for @stageMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging video and audio'**
  String get stageMerging;

  /// No description provided for @stageSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get stageSaving;

  /// No description provided for @stageSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get stageSaved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
