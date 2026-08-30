import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static Future<void> downloadUpdate(String url) async {
    // Android 8+ "install unknown apps" permission — if not granted, the
    // system installer will prompt for it when the user taps to install,
    // so we don't block the download on this.
    await Permission.requestInstallPackages.request();

    final dir = await getExternalStorageDirectory();
    if (dir == null) return;

    final fileName = url.split('/').last;

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
    );
  }
}
