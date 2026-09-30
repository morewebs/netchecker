import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/settings/app_settings.dart';
import 'package:netchecker/probe/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'migrates legacy pin preference, bounds values and removes invalid hosts',
    () async {
      SharedPreferences.setMockInitialValues({
        'alwaysOnTop': true,
        'httpTimeoutMs': -1,
        'extraDomains': ['Example.com', 'https://example.com/', 'not valid'],
        'exportFormat': 'bad',
        'maxRounds': 4,
      });
      final prefs = await SharedPreferences.getInstance(),
          s = AppSettings.fromPrefs(await SharedPreferences.getInstance());
      expect(s.compactMode, isTrue);
      expect(s.httpTimeoutMs, 500);
      expect(s.extraDomains, ['https://example.com/']);
      expect(s.exportFormat, 'markdown');
      await s.copyWith(compactMode: false).save(prefs);
      expect(prefs.containsKey('maxRounds'), isFalse);
      expect(AppSettings.fromPrefs(prefs).compactMode, isFalse);
    },
  );
  test('validates and canonicalizes HTTPS targets', () {
    expect(parseWebsite('EXAMPLE.com.').toString(), 'https://example.com/');
    expect(parseWebsite('https://example.com:8443/status?q=1').port, 8443);
    expect(parseWebsite('::1').host, '::1');
    for (final value in [
      '',
      'a b',
      'http://example.com',
      'https://user:secret@example.com',
      'https://x:99999',
      '-bad.com',
    ]) {
      expect(() => parseWebsite(value), throwsFormatException);
    }
    expect(() => parseDnsName('1.1.1.1'), throwsFormatException);
  });
  test('address scope is parsed without labeling domains as poisoning', () {
    for (final ip in [
      '10.1.1.1',
      '172.31.0.1',
      '198.19.1.1',
      '::1',
      'fe90::1',
      '::ffff:192.168.1.1',
    ]) {
      expect(isNonPublicAddress(ip), isTrue, reason: ip);
    }
    for (final ip in [
      '1.1.1.1',
      '8.8.8.8',
      'fc-example.com',
      '185.88.153.235',
    ]) {
      expect(isNonPublicAddress(ip), isFalse, reason: ip);
    }
  });
}
