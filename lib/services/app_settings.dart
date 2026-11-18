import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_quality.dart';

/// User settings. The download folder is an Android SAF tree URI.
class AppSettings extends ChangeNotifier {
  static const _uriKey = 'folderUri';
  static const _nameKey = 'folderName';
  static const _qualityKey = 'videoQuality';
  static const _showOlderFilesKey = 'showOlderFiles';
  static const _trimLeadingSilenceKey = 'trimLeadingSilence';
  static const _silenceThresholdDbKey = 'silenceThresholdDb';

  static const minSilenceThresholdDb = -80;
  static const maxSilenceThresholdDb = -20;
  static const defaultSilenceThresholdDb = -50;

  String? _folderUri;
  String? _folderName;
  VideoQuality _videoQuality = VideoQuality.defaultQuality;
  bool _showOlderFiles = false;
  bool _trimLeadingSilence = false;
  int _silenceThresholdDb = defaultSilenceThresholdDb;

  String? get folderUri => _folderUri;

  /// Display name of the chosen folder, null when the default is used.
  String? get folderName => _folderName;

  /// Default video height used for new downloads.
  VideoQuality get videoQuality => _videoQuality;
  bool get showOlderFiles => _showOlderFiles;
  bool get trimLeadingSilence => _trimLeadingSilence;
  int get silenceThresholdDb => _silenceThresholdDb;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _folderUri = prefs.getString(_uriKey);
    _folderName = prefs.getString(_nameKey);
    _videoQuality = VideoQuality.fromName(prefs.getString(_qualityKey));
    _showOlderFiles = prefs.getBool(_showOlderFilesKey) ?? false;
    final trim = prefs.get(_trimLeadingSilenceKey);
    _trimLeadingSilence = trim is bool ? trim : false;
    if (trim != null && trim is! bool) {
      if (!await prefs.setBool(_trimLeadingSilenceKey, false)) {
        throw StateError('Could not reset setting');
      }
    }
    final threshold = prefs.get(_silenceThresholdDbKey);
    if (threshold is int &&
        threshold >= minSilenceThresholdDb &&
        threshold <= maxSilenceThresholdDb) {
      _silenceThresholdDb = threshold;
    } else {
      _silenceThresholdDb = defaultSilenceThresholdDb;
      if (threshold != null &&
          !await prefs.setInt(
            _silenceThresholdDbKey,
            defaultSilenceThresholdDb,
          )) {
        throw StateError('Could not reset setting');
      }
    }
    notifyListeners();
  }

  Future<void> setTrimLeadingSilence(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_trimLeadingSilenceKey, value)) {
      throw StateError('Could not save setting');
    }
    _trimLeadingSilence = value;
    notifyListeners();
  }

  Future<void> setSilenceThresholdDb(int value) async {
    if (value < minSilenceThresholdDb || value > maxSilenceThresholdDb) {
      throw RangeError.range(
        value,
        minSilenceThresholdDb,
        maxSilenceThresholdDb,
        'value',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_silenceThresholdDbKey, value)) {
      throw StateError('Could not save setting');
    }
    _silenceThresholdDb = value;
    notifyListeners();
  }

  Future<void> setShowOlderFiles(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_showOlderFilesKey, value)) {
      throw StateError('Could not save setting');
    }
    _showOlderFiles = value;
    notifyListeners();
  }

  Future<void> setVideoQuality(VideoQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, quality.name);
    _videoQuality = quality;
    notifyListeners();
  }

  Future<void> setFolder(String uri, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uriKey, uri);
    await prefs.setString(_nameKey, name);
    _folderUri = uri;
    _folderName = name;
    notifyListeners();
  }

  Future<void> resetFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uriKey);
    await prefs.remove(_nameKey);
    _folderUri = null;
    _folderName = null;
    notifyListeners();
  }
}
