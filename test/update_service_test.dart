import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/data/update_service.dart';
import 'package:netchecker/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UpdateService semver comparison', () {
    test('standard semver comparisons', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.2.0', '1.1.9'), isFalse);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });

    test('semver with v prefix', () {
      expect(UpdateService.isNewerVersion('v1.0.0', 'v1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.1', 'v1.0.0'), isFalse);
    });

    test('semver with build numbers', () {
      expect(UpdateService.isNewerVersion('1.0.0+1', '1.0.0+2'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0+2', '1.0.0+1'), isFalse);
      expect(UpdateService.isNewerVersion('v1.0.0+1', 'v1.0.1+1'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0+1'), isTrue);
    });
  });

  group('ReleaseInfo JSON Parsing', () {
    test('prereleases and malformed versions are ordered safely', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0-beta.1'), isFalse);
      expect(
        UpdateService.isNewerVersion('1.0.0-beta.2', '1.0.0-beta.10'),
        isTrue,
      );
      expect(UpdateService.isNewerVersion('1.0.0-beta.10', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion(' 1.0.0-beta ', ' 1.0.0 '), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', 'nightly'), isFalse);
    });
    test('assets cannot cross platform or silently choose an Android ABI', () {
      final release = ReleaseInfo.fromJson({
        'assets': [
          {'name': 'netchecker-linux.zip'},
          {'name': 'app-arm64-v8a-release.apk'},
          {'name': 'netchecker-universal.APK'},
        ],
      });
      expect(release.windowsAsset, isNull);
      expect(release.apkAsset?.name, 'netchecker-universal.APK');
      expect(release.linuxAsset?.name, 'netchecker-linux.zip');
    });
    test('correctly parses GitHub release payload and assets', () {
      final sampleJson = {
        'tag_name': 'v1.2.0',
        'name': 'NetChecker 1.2.0 Release',
        'body': '## Features\n- Added automatic updater\n- Faster DNS probe',
        'html_url':
            'https://github.com/morewebs/netchecker/releases/tag/v1.2.0',
        'published_at': '2026-08-20T12:00:00Z',
        'assets': [
          {
            'name': 'netchecker-arm64-v8a.apk',
            'browser_download_url':
                'https://github.com/morewebs/netchecker/releases/download/v1.2.0/netchecker-arm64-v8a.apk',
            'size': 15204800,
            'content_type': 'application/vnd.android.package-archive',
          },
          {
            'name': 'netchecker-windows.zip',
            'browser_download_url':
                'https://github.com/morewebs/netchecker/releases/download/v1.2.0/netchecker-windows.zip',
            'size': 24500000,
            'content_type': 'application/zip',
          },
          {
            'name': 'netchecker.deb',
            'browser_download_url':
                'https://github.com/morewebs/netchecker/releases/download/v1.2.0/netchecker.deb',
            'size': 18900000,
            'content_type': 'application/vnd.debian.binary-package',
          },
        ],
      };

      final release = ReleaseInfo.fromJson(sampleJson);

      expect(release.tagName, 'v1.2.0');
      expect(release.name, 'NetChecker 1.2.0 Release');
      expect(release.body, contains('Added automatic updater'));
      expect(
        release.htmlUrl,
        'https://github.com/morewebs/netchecker/releases/tag/v1.2.0',
      );
      expect(release.publishedAt, isNotNull);
      expect(release.assets.length, 3);

      // Never offer an arbitrary ABI-specific APK to an unknown device.
      expect(release.apkAsset, isNull);
      expect(release.windowsAsset?.name, 'netchecker-windows.zip');
      expect(release.linuxAsset?.name, 'netchecker.deb');
    });
  });

  group('AppSettings autoCheckUpdates serialization', () {
    test('defaults and persists autoCheckUpdates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final defaultSettings = AppSettings();
      expect(defaultSettings.autoCheckUpdates, isTrue);

      final modified = defaultSettings.copyWith(autoCheckUpdates: false);
      expect(modified.autoCheckUpdates, isFalse);

      await modified.save(prefs);
      final reloaded = AppSettings.fromPrefs(prefs);
      expect(reloaded.autoCheckUpdates, isFalse);
    });
  });
}
