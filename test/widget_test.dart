import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netchecker/app.dart';
import 'package:netchecker/probe/engine.dart';
import 'package:netchecker/ui/profile/item_profile_page.dart';
import 'package:netchecker/ui/report_page.dart';
import 'package:netchecker/ui/session_page.dart';
import 'package:netchecker/ui/settings_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_transport.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Future<ProbeEngine> setup(
    WidgetTester tester, {
    bool desktop = false,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({'autoCheckUpdates': false});
    final engine = ProbeEngine(transport: FakeTransport());
    await engine.start(loops: false, loadNics: false);
    addTearDown(engine.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: NetCheckerApp(engine: engine, forceDesktop: desktop),
      ),
    );
    await tester.pump();
    return engine;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('phone monitor preserves live-first behavior and opens details', (
    tester,
  ) async {
    final engine = await setup(tester);
    expect(find.text('Live monitor'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(engine.isRunning, isFalse);
    await tester.tap(find.text('youtube.com').first);
    await tester.pumpAndSettle();
    expect(find.byType(ItemProfilePage), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
    expect(find.text('What this checks'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('search, favorites and filtering use stable target state', (
    tester,
  ) async {
    final engine = await setup(tester);
    await tester.enterText(find.byType(TextField), 'github');
    await tester.pump();
    expect(find.text('github.com'), findsOneWidget);
    expect(find.text('youtube.com'), findsNothing);
    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pump();
    expect(engine.settings.favorites.length, 1);
    await tester.tap(find.text('Favorites'));
    await tester.pump();
    expect(find.text('github.com'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('wide desktop keeps a persistent inspector and report scaffold', (
    tester,
  ) async {
    final engine = await setup(
      tester,
      desktop: true,
      size: const Size(1280, 820),
    );
    expect(find.text('Select a target'), findsOneWidget);
    await tester.tap(find.text('youtube.com').first);
    await tester.pump();
    expect(find.byType(TargetInspector), findsOneWidget);
    expect(find.byType(ItemProfilePage), findsNothing);
    await engine.runNow(engine.targets.first);
    await tester.pump();
    expect(find.text('HTTP 200'), findsWidgets);
    await tester.tap(find.byTooltip('Monitor actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export report'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPage), findsOneWidget);
    await tester.tap(find.text('Copy report'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
  testWidgets(
    'settings validates targets and preserves editable text shortcuts',
    (tester) async {
      await setup(tester, desktop: true, size: const Size(800, 900));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 's r c');
      await tester.pump();
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.byTooltip('Monitor actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsForm), findsOneWidget);
      await finish(tester);
    },
  );
  testWidgets('keyboard pause works outside text inputs', (tester) async {
    final engine = await setup(tester, desktop: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(engine.isRunning, isFalse);
    await finish(tester);
  });
  for (final size in [
    const Size(320, 640),
    const Size(420, 640),
    const Size(800, 600),
  ]) {
    testWidgets('responsive layout has no overflow at $size', (tester) async {
      await setup(tester, desktop: size.width != 320, size: size);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
    testWidgets('large text has no overflow at $size', (tester) async {
      await setup(tester, desktop: size.width != 320, size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('youtube.com').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('youtube.com').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ItemProfilePage), findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets(
    'privacy hides targets in monitor, details and report at large text',
    (tester) async {
      final engine = await setup(tester, size: const Size(320, 640), scale: 2);
      await engine.runNow(engine.targets.first);
      await engine.apply(engine.settings.copyWith(privacyMode: true));
      await tester.pump();
      expect(find.text('youtube.com'), findsNothing);
      await tester.tap(find.byTooltip('Monitor actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export report'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportPage), findsOneWidget);
      expect(find.textContaining('youtube.com'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Privacy mode keeps redaction on.').hitTestable(),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ReportPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('session baseline and target exclusion stay actionable', (
    tester,
  ) async {
    final engine = await setup(tester);
    await engine.runNow(engine.targets.first);
    await tester.tap(find.byTooltip('Target actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exclude from monitoring'));
    await tester.pumpAndSettle();
    expect(engine.enabled(engine.targets.first.key), isFalse);
    await engine.runNow(engine.targets[1]);
    await tester.tap(find.byTooltip('Monitor actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session & comparison'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionPage), findsOneWidget);
    await tester.tap(find.text('Capture baseline'));
    await tester.pumpAndSettle();
    expect(engine.baseline, isNotNull);
    expect(find.text('Replace baseline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('invalid settings explain the problem before applying', (
    tester,
  ) async {
    await setup(tester, size: const Size(320, 640), scale: 2);
    await tester.tap(find.byTooltip('Monitor actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextFormField, 'Custom websites');
    await tester.scrollUntilVisible(
      field,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, 'http://insecure.example');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(field).validator!('http://insecure.example'),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
