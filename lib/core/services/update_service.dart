import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// One status/progress tick for a download task — see
/// UpdateService.statusStream.
class DownloadStatusEvent {
  final String taskId;
  final DownloadTaskStatus status;
  final int progress;

  DownloadStatusEvent({required this.taskId, required this.status, required this.progress});
}

const String _downloaderPortName = 'bahi_downloader_send_port';

// Must be a top-level or static function (flutter_downloader's own
// requirement — it runs in a separate background isolate, not the UI
// isolate) — just relays the tick across via the named port registered
// in UpdateService.initDownloadListener().
@pragma('vm:entry-point')
void _downloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName(_downloaderPortName);
  send?.send([id, status, progress]);
}

/// GitHub Releases convention (plan §8):
/// - tag = v<major>.<minor>.<patch> (e.g. v1.0.0)
/// - release asset name ends in .apk (e.g. bahi-v1.0.0.apk)
const String _githubRepo = 'shubhiscoding/Bahi';

class UpdateInfo {
  final String version;
  final String downloadUrl;

  UpdateInfo({required this.version, required this.downloadUrl});
}

/// Checks GitHub Releases for a newer version than the one currently
/// installed, and handles downloading + opening the installer.
class UpdateService {
  static final _statusController = StreamController<DownloadStatusEvent>.broadcast();
  static ReceivePort? _port;

  /// Emits every status/progress tick for any active download task —
  /// filter by taskId to track one specific download. Without this, the
  /// app had literally no way to know a download had failed/been
  /// canceled (e.g. by Android's requiresStorageNotLow constraint on
  /// devices it considers low on space) — it just silently never
  /// finished, matching the "download starts then stops" report.
  static Stream<DownloadStatusEvent> get statusStream => _statusController.stream;

  /// Call once at app startup (see main.dart), after
  /// FlutterDownloader.initialize().
  static void initDownloadListener() {
    if (_port != null) return; // already registered
    _port = ReceivePort();
    IsolateNameServer.registerPortWithName(_port!.sendPort, _downloaderPortName);
    _port!.listen((data) {
      final list = data as List<dynamic>;
      _statusController.add(
        DownloadStatusEvent(
          taskId: list[0] as String,
          status: DownloadTaskStatus.fromInt(list[1] as int),
          progress: list[2] as int,
        ),
      );
    });
    FlutterDownloader.registerCallback(_downloadCallback);
  }

  /// Returns update info if a newer release exists, null otherwise
  /// (including on any network/parsing failure — a failed check should
  /// never block or error the app, just silently mean "no update found").
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_githubRepo/releases/latest',
      );

      final tagName = response.data['tag_name'] as String; // e.g. "v1.0.0"
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!_isNewer(latestVersion, currentVersion)) return null;

      final assets = response.data['assets'] as List;
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String).endsWith('.apk'),
            orElse: () => {},
          );

      final downloadUrl = apkAsset['browser_download_url'] as String?;
      if (downloadUrl == null) return null;

      return UpdateInfo(version: latestVersion, downloadUrl: downloadUrl);
    } catch (e) {
      print('Update check failed: $e');
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  /// Downloads the update APK in the background. The system shows its own
  /// download notification (showNotification: true) that opens the
  /// installer when tapped once complete (openFileFromNotification: true)
  /// — satisfies "download silently, notify when ready to install"
  /// without needing a custom in-app progress UI.
  ///
  /// Returns the task ID — the caller should watch [statusStream] filtered
  /// to this ID for failed/canceled ticks, since enqueue() only confirms
  /// the job was *scheduled*, not that it ever completes.
  ///
  /// Throws on failure (directory couldn't be resolved/created, enqueue
  /// returned no task ID) — the caller must surface this to the user;
  /// silently swallowing it is exactly what made downloads appear to do
  /// nothing when this failed previously.
  static Future<String> downloadUpdate(String url) async {
    // Android 8+ "install unknown apps" permission — if not granted, the
    // system installer will prompt for it when the user taps to install,
    // so we don't block the download on this.
    await Permission.requestInstallPackages.request();
    // Android 13+ requires this for showNotification to actually post one.
    await Permission.notification.request();

    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('डाउनलोड फ़ोल्डर नहीं मिला');
    }

    // flutter_downloader's own docs: "the directory must be created in
    // advance" — enqueue() fails silently (no exception, no task) if it
    // doesn't already exist, which was the actual root cause of nothing
    // happening on tap.
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final fileName = url.split('/').last;

    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      // Defaults to true, which maps to WorkManager's
      // setRequiresStorageNotLow constraint — on a phone Android
      // considers low on storage (a common state on budget/older
      // devices, and the threshold varies by OEM), the job gets
      // cancelled outright with nothing surfaced. An app-update APK is
      // small and one-shot; don't gate it on this.
      requiresStorageNotLow: false,
    );

    if (taskId == null) {
      throw Exception('डाउनलोड शुरू नहीं हो सका');
    }
    return taskId;
  }
}
