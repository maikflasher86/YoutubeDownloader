# Youtube Downloader & MP3

Flutter app (Android and Windows) that downloads YouTube videos as MP4 or MP3.
Version 0.1.0. For private use only. Developer: Maik Neumann.

## Features

- Download a video as MP4 or as MP3 from a YouTube link.
- Android: the app appears in the YouTube share sheet, so you need not copy the link.
- Windows: paste the link into the app.
- Video quality choice per download (360p, 480p, 720p, 1080p). Set the default in Settings.
- Settings: choose the download folder. Audio and video go into the subfolders `Audio` and `Video`.
- Tap a finished download to open it with the default player.
- Imprint page with version number.
- Dark Material 3 theme.

Default folders without a setting:
- Android: `Music` and `Movies`.
- Windows: `%USERPROFILE%\Music\YouTube Downloader` and `%USERPROFILE%\Videos\YouTube Downloader`.

## Known limits

- YouTube returns HTTP 403 for audio-only streams and for HD video-only streams after the first MB.
  - MP3: the app extracts the audio from the muxed 360p stream.
  - Video: the app falls back to the muxed 360p stream when an HD download fails.
  - Result: 360p is the reliable quality today.
- The Android merge of HD video and audio is not tested on a device.

## Requirements

- Flutter SDK.
- Android: ffmpeg is included through `ffmpeg_kit_flutter_new_audio`.
- Windows: `ffmpeg.exe` must be in `PATH` or next to `youtube_downloader.exe`.

## Build and test

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build windows --release
```

Windows output: `build\windows\x64\runner\Release\youtube_downloader.exe`.
If the Windows build fails once with `C1041` (PDB lock), run it again.

## Windows installer (MSI)

The CI builds an MSI with WiX (`installer/Package.wxs`). Local build after `flutter build windows --release` and copying `ffmpeg.exe` into the Release folder:

```powershell
dotnet tool install --global wix --version 5.0.2
wix build installer\Package.wxs -d Version=0.1.0 -d SourceDir=(Resolve-Path build\windows\x64\runner\Release).Path -arch x64 -o YouTube-Downloader-0.1.0.msi
```
The installer is unsigned, so SmartScreen shows a warning.

## Libraries

`youtube_explode_dart` (stream manifest), `provider` (state), `receive_sharing_intent` (share sheet),
`ffmpeg_kit_flutter_new_audio` (Android audio and merge), `media_store_plus`, `saf_util` and `saf_stream` (Android storage),
`android_intent_plus` (open files), `file_picker` (Windows folder picker),
`shared_preferences` (settings), `package_info_plus` (version).
