import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Selectable video heights in pixels.
const videoQualities = [360, 480, 720, 1080];

/// Default height: 720p suits modern phone screens and keeps files small.
const defaultVideoQuality = 720;

/// User settings. The download folder is an Android SAF tree URI.
class AppSettings extends ChangeNotifier {
  static const _uriKey = 'folderUri';
  static const _nameKey = 'folderName';
  static const _qualityKey = 'videoQuality';

  String? _folderUri;
  String? _folderName;
  int _videoQuality = defaultVideoQuality;

  String? get folderUri => _folderUri;

  /// Display name of the chosen folder, null when the default is used.
  String? get folderName => _folderName;

  /// Default video height used for new downloads.
  int get videoQuality => _videoQuality;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _folderUri = prefs.getString(_uriKey);
    _folderName = prefs.getString(_nameKey);
    final q = prefs.getInt(_qualityKey);
    _videoQuality = videoQualities.contains(q) ? q! : defaultVideoQuality;
    notifyListeners();
  }

  Future<void> setVideoQuality(int height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_qualityKey, height);
    _videoQuality = height;
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
