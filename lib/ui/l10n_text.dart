import '../l10n/app_localizations.dart';
import '../models/download_item.dart';
import 'app_state.dart';

extension DownloadStageText on DownloadStage {
  String text(AppLocalizations l) => switch (this) {
    DownloadStage.queued => l.stageQueued,
    DownloadStage.starting => l.stageStarting,
    DownloadStage.downloading => l.stageDownloading,
    DownloadStage.downloadingVideo => l.stageDownloadingVideo,
    DownloadStage.downloadingAudio => l.stageDownloadingAudio,
    DownloadStage.converting => l.stageConverting,
    DownloadStage.merging => l.stageMerging,
    DownloadStage.saving => l.stageSaving,
    DownloadStage.saved => l.stageSaved,
  };
}

extension AppErrorText on AppError {
  String text(AppLocalizations l) => switch (kind) {
    AppErrorKind.invalidLink => l.errorInvalidLink,
    AppErrorKind.load => l.errorLoad(details ?? ''),
    AppErrorKind.open => l.errorOpen(details ?? ''),
  };
}
