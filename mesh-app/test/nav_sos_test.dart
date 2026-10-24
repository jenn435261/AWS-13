import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/features/shell/help_button.dart';
import 'package:mesh_app/features/sos/sos_text.dart';
import 'package:mesh_app/l10n/gen/app_localizations_en.dart';
import 'package:mesh_app/models/network.dart';
import 'package:mesh_app/state/settings_controller.dart';
import 'package:mesh_app/ui/surfaces.dart';

import 'test_app.dart';

final _noRoute = NetworkStatus(
  internet: false,
  peers: 0,
  node: false,
  lora: false,
  gatewayOnline: false,
  lastSync: DateTime.utc(2026, 1, 1),
  lastGlobalSync: DateTime.utc(2026, 1, 1),
);

const _ana = EmergencyContact(name: 'Ana', phone: '+1 (408) 555-0100');

String _path(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await TestApp.settle(tester);
}

Future<void> _hold(
  WidgetTester tester,
  Finder target,
  Duration duration,
) async {
  await tester.ensureVisible(target);
  await tester.pump();
  final finger = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(duration);
  await tester.pump(const Duration(milliseconds: 200));
  await finger.up();
  await TestApp.settle(tester);
}

/// The undo toast sits on the bottom actions. Hide it before tapping them.
Future<void> _hideToast(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .hideCurrentSnackBar();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final l10n = AppLocalizationsEn();

  test('a text link matches the phone, and 911 is a tel link', () {
    final ios = smsUri(
      ['+14085550100', '4085550199'],
      'Need help',
      platform: TargetPlatform.iOS,
    );
    expect(ios.scheme, 'sms');
    expect(ios.path, '/open');
    expect(ios.queryParameters['addresses'], '+14085550100,4085550199');
    expect(ios.queryParameters['body'], 'Need help');
    expect(smsUri(['1'], 'a', platform: TargetPlatform.macOS).path, '/open');

    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      final uri = smsUri(['+14085550100', '555'], 'Hi', platform: platform);
      expect(uri.scheme, 'sms');
      expect(uri.queryParameters['body'], 'Hi');
      expect(uri.toString(), startsWith('sms:+14085550100,555?body='));
    }

    expect(emergencyCallUri.scheme, 'tel');
    expect(emergencyCallUri.path, '911');
  });

  test('the SOS text names who, where and when', () {
    final at = DateTime(2026, 10, 24, 9, 5);
    const point = LatLng(37.3352, -121.8811);

    expect(
      sosTextBody(l10n, name: 'Ana', point: point, place: 'Library', at: at),
      'SOS from Ana. I need help. Location: Library (37.33520, -121.88110). Time: 2026-10-24 09:05.',
    );
    expect(
      sosTextBody(l10n, name: 'Ana', point: point, place: '  ', at: at),
      'SOS from Ana. I need help. Location: 37.33520, -121.88110. Time: 2026-10-24 09:05.',
    );
    expect(
      sosTextBody(l10n, name: 'Ana', point: null, place: 'Lobby', at: at),
      'SOS from Ana. I need help. Location: Lobby. Time: 2026-10-24 09:05.',
    );
    expect(
      sosTextBody(l10n, name: null, point: null, place: '', at: at),
      'SOS. I need help. Location: unknown. Time: 2026-10-24 09:05.',
    );
    expect(
      sosTextBody(l10n, name: '  ', point: null, place: '', at: at),
      contains('Location: unknown.'),
    );
  });

  test('a phone number is checked and dialable, and only five are kept', () {
    expect(dialableNumber('+1 (408) 555-0100'), '+14085550100');
    expect(dialableNumber('408.555.0100'), '4085550100');
    expect(isValidPhone('911'), isTrue);
    expect(isValidPhone('+1 408 555 0100'), isTrue);
    expect(isValidPhone('12'), isFalse);
    expect(isValidPhone('call me'), isFalse);
    expect(isValidPhone(''), isFalse);

    expect(_ana.dialable, '+14085550100');
    expect(EmergencyContact.fromJson(_ana.toJson()), _ana);
    expect(EmergencyContact.fromJson({'name': 1}), isNull);

    final settings = SettingsController(store: MemorySettingsStore());
    addTearDown(settings.dispose);
    settings.emergencyContacts = [
      for (var i = 0; i < 6; i++)
        EmergencyContact(name: 'P$i', phone: '555010$i'),
    ];
    expect(settings.emergencyContacts, hasLength(maxEmergencyContacts));
    expect(
      settings.saveEmergencyContact(
        const EmergencyContact(name: 'Extra', phone: '5550199'),
      ),
      isFalse,
    );
    expect(
      settings.saveEmergencyContact(
        const EmergencyContact(name: 'New', phone: '5550199'),
        index: 0,
      ),
      isTrue,
    );
    expect(settings.emergencyContacts.first.name, 'New');
  });

  testWidgets('emergency contacts are added, edited and removed with undo', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    await _go(tester, '/more/emergency-contacts');
    expect(find.text('No emergency contacts yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(MainButton, 'Add emergency contact'));
    await TestApp.settle(tester);
    expect(_path(tester), '/emergency-contact');

    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await TestApp.settle(tester);
    expect(
      find.text('Check the number: use digits, and + before a country code'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MainButton>(find.widgetWithText(MainButton, 'Save'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(1), '+1 (408) 555-0100');
    await TestApp.settle(tester);
    await tester.tap(find.widgetWithText(MainButton, 'Save'));
    await TestApp.settle(tester);
    expect(_path(tester), '/more/emergency-contacts');
    expect(app.settings.emergencyContacts, [_ana]);
    expect(find.text('Ana saved'), findsOneWidget);

    await _hideToast(tester);
    await tester.tap(find.text('Ana'));
    await TestApp.settle(tester);
    expect(find.text('Edit emergency contact'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Ana Ruiz');
    await tester.tap(find.widgetWithText(MainButton, 'Save'));
    await TestApp.settle(tester);
    expect(app.settings.emergencyContacts.single.name, 'Ana Ruiz');

    await _hideToast(tester);
    await tester.tap(find.byTooltip('Remove Ana Ruiz'));
    await TestApp.settle(tester);
    expect(app.settings.emergencyContacts, isEmpty);
    expect(find.text('Ana Ruiz removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await TestApp.settle(tester);
    expect(app.settings.emergencyContacts.single.name, 'Ana Ruiz');

    await tester.tap(find.text('Redo'));
    await TestApp.settle(tester);
    expect(app.settings.emergencyContacts, isEmpty);
    await TestApp.close(tester);
  });

  testWidgets('the add button stops at five emergency contacts', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    app.settings.emergencyContacts = [
      for (var i = 0; i < maxEmergencyContacts; i++)
        EmergencyContact(name: 'Person $i', phone: '408555010$i'),
    ];
    await app.pump(tester);
    await _go(tester, '/more/emergency-contacts');

    expect(
      find.text('You can save up to 5 emergency contacts.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MainButton>(
            find.widgetWithText(MainButton, 'Add emergency contact'),
          )
          .onPressed,
      isNull,
    );
    await TestApp.close(tester);
  });

  testWidgets('an SOS with no route offers a text and a 911 call', (
    tester,
  ) async {
    final launched = <Uri>[];
    final previous = launchOnPhone;
    launchOnPhone = (uri) async {
      launched.add(uri);
      return true;
    };
    addTearDown(() => launchOnPhone = previous);

    final app = await TestApp.create(tester);
    app.settings.emergencyContacts = const [_ana];
    app.repository.debugSetNetwork(_noRoute);
    await app.pump(tester);
    // After the demo point has loaded, or that load would replace this.
    await app.repository.setManualLocation(
      const LatLng(37.3352, -121.8811),
      label: 'Library',
    );
    await TestApp.settle(tester);

    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));
    expect(find.text('No network reached'), findsOneWidget);
    expect(_path(tester), startsWith('/sos/'));
    expect(
      find.textContaining('Library (37.33520, -121.88110)'),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Text 1 emergency contact'),
      ),
      findsOneWidget,
    );

    await _hideToast(tester);
    await tester.tap(find.text('Text 1 emergency contact'));
    await TestApp.settle(tester);
    final body = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.contains('Library'));
    expect(launched.single, smsUri([_ana.dialable], body));
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Call 911'));
    await TestApp.settle(tester);
    expect(launched.last, emergencyCallUri);

    // This step has Close, not Back. Closing it leaves the SOS request.
    await tester.tap(find.byTooltip('Close'));
    await TestApp.settle(tester);
    expect(find.text('No network reached'), findsNothing);
    expect(_path(tester), startsWith('/more/requests/sos'));
    await tester.pageBack();
    await TestApp.settle(tester);
    expect(_path(tester), '/map');
    await TestApp.close(tester);
  });

  testWidgets('with no emergency contacts, Call 911 is the main action', (
    tester,
  ) async {
    final launched = <Uri>[];
    final previous = launchOnPhone;
    launchOnPhone = (uri) async {
      launched.add(uri);
      return uri.scheme == 'tel';
    };
    addTearDown(() => launchOnPhone = previous);

    final app = await TestApp.create(tester);
    app.repository.debugSetNetwork(_noRoute);
    await app.pump(tester);
    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));

    expect(find.text('No network reached'), findsOneWidget);
    expect(find.textContaining('Call 911 now if you can.'), findsOneWidget);
    expect(find.text('Text 1 emergency contact'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Call 911'),
      ),
      findsOneWidget,
    );

    await _hideToast(tester);
    await tester.tap(find.text('Call 911'));
    await TestApp.settle(tester);
    expect(launched.single, emergencyCallUri);

    launchOnPhone = (uri) async => false;
    await tester.tap(find.text('Add emergency contacts'));
    await TestApp.settle(tester);
    expect(_path(tester), '/emergency-contact');
    await tester.pageBack();
    await TestApp.settle(tester);

    await tester.tap(find.text('Call 911'));
    await TestApp.settle(tester);
    expect(
      find.text(
        'This phone couldn\'t open that. Try again, or use your phone\'s own app.',
      ),
      findsOneWidget,
    );
    await TestApp.close(tester);
  });

  testWidgets('SOS from the lock screen opens the no-network screen', (
    tester,
  ) async {
    final launched = <Uri>[];
    final previous = launchOnPhone;
    launchOnPhone = (uri) async {
      launched.add(uri);
      return true;
    };
    addTearDown(() => launchOnPhone = previous);

    final app = await TestApp.create(tester);
    app.settings.emergencyContacts = const [_ana];
    app.repository.debugSetNetwork(_noRoute);
    await app.pump(tester);

    app.lock.lock();
    await TestApp.settle(tester);
    expect(find.text('Mesh is locked'), findsOneWidget);

    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));

    // The lock covers the app's routes, so this screen is on the lock's own stack.
    expect(find.text('No network reached'), findsOneWidget);
    expect(find.text('Text 1 emergency contact'), findsOneWidget);
    expect(_path(tester), '/map');
    expect(app.repository.requests.value.where((r) => r.sos), hasLength(1));

    await _hideToast(tester);
    await tester.tap(find.text('Text 1 emergency contact'));
    await TestApp.settle(tester);
    expect(launched.single.scheme, 'sms');
    expect(launched.single.toString(), contains('14085550100'));

    await tester.tap(find.text('Call 911'));
    await TestApp.settle(tester);
    expect(launched.last, emergencyCallUri);

    await tester.tap(find.byTooltip('Close'));
    await TestApp.settle(tester);
    expect(find.text('No network reached'), findsNothing);
    expect(find.text('Mesh is locked'), findsOneWidget);
    await TestApp.close(tester);
  });

  testWidgets('SOS from the lock screen stays there when a route exists', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pump(tester);
    app.lock.lock();
    await TestApp.settle(tester);

    await _hold(tester, find.byType(HelpButton), const Duration(seconds: 2));

    expect(app.repository.requests.value.where((r) => r.sos), hasLength(1));
    expect(find.text('No network reached'), findsNothing);
    expect(find.text('Mesh is locked'), findsOneWidget);
    expect(_path(tester), '/map');
    await TestApp.close(tester);
  });
}
