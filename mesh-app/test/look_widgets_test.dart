import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mesh_app/l10n/gen/app_localizations.dart';
import 'package:mesh_app/models/resource.dart';
import 'package:skeletonizer/skeletonizer.dart';
// ResourceBadge and resourceMark must still come from their old home.
import 'package:mesh_app/features/resources/resource_sheet.dart';
import 'package:mesh_app/ui/action_bar.dart';
import 'package:mesh_app/ui/advanced_section.dart';
import 'package:mesh_app/ui/empty_state.dart';
import 'package:mesh_app/ui/info_chip.dart';
import 'package:mesh_app/ui/skeletons.dart';
import 'package:mesh_app/ui/stage_list.dart';
import 'package:mesh_app/ui/surfaces.dart';
import 'package:mesh_app/ui/theme.dart';

Future<void> _show(WidgetTester tester, Widget child, {double textScale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: ListView(children: [child])),
    ),
  ));
  await tester.pump();
}

const _stages = [
  StageItem(icon: Icons.smartphone, title: 'Saved', detail: '10:00', state: StageState.done),
  StageItem(icon: Icons.cell_tower, title: 'Sent', state: StageState.current),
  StageItem(icon: Icons.task_alt, title: 'Helped', detail: 'Waiting', state: StageState.upcoming),
];

void main() {
  group('StageList', () {
    testWidgets('reads each stage with its state, not just its color', (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(tester, const StageList(stages: _stages));

      expect(find.bySemanticsLabel('Done. Saved. 10:00'), findsOneWidget);
      expect(find.bySemanticsLabel('Now. Sent'), findsOneWidget);
      expect(find.bySemanticsLabel('Not yet. Helped. Waiting'), findsOneWidget);
      // Done stages swap their icon for a check; the others keep theirs.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.smartphone), findsNothing);
      expect(find.byIcon(Icons.cell_tower), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('only a waiting current stage pulses', (tester) async {
      await _show(tester, const StageList(stages: _stages));
      expect(find.byType(Pulse), findsNothing);

      await _show(tester, const StageList(stages: _stages, waiting: true));
      expect(find.byType(Pulse), findsOneWidget);
      expect(
        find.ancestor(of: find.byIcon(Icons.cell_tower), matching: find.byType(Pulse)),
        findsOneWidget,
      );
    });
  });

  group('ActionBar', () {
    final primary = FilledButton(onPressed: () {}, child: const Text('Main'));
    final secondary = OutlinedButton(onPressed: () {}, child: const Text('Other'));

    testWidgets('draws nothing without a main action', (tester) async {
      await _show(tester, const ActionBar(primary: null, secondary: Text('Other')));
      expect(find.text('Other', skipOffstage: false), findsNothing);
      expect(find.byType(SafeArea, skipOffstage: false), findsNothing);
    });

    testWidgets('puts the main action on the right, wider', (tester) async {
      await _show(tester, ActionBar(primary: primary, secondary: secondary));
      final main = tester.getRect(find.byWidget(primary));
      final other = tester.getRect(find.byWidget(secondary));
      expect(main.left, greaterThan(other.right));
      expect(main.width, greaterThan(other.width));
      expect(main.height, greaterThanOrEqualTo(48));
    });

    testWidgets('stacks the actions at large text, main one at the bottom', (tester) async {
      await _show(tester, ActionBar(primary: primary, secondary: secondary), textScale: 1.5);
      final main = tester.getRect(find.byWidget(primary));
      final other = tester.getRect(find.byWidget(secondary));
      expect(main.top, greaterThan(other.bottom));
      expect(main.width, other.width);
    });

    testWidgets('shows a note above the buttons', (tester) async {
      await _show(tester, ActionBar(primary: primary, note: const Text('Before you tap')));
      expect(
        tester.getRect(find.text('Before you tap')).bottom,
        lessThan(tester.getRect(find.byWidget(primary)).top),
      );
    });
  });

  testWidgets('EmptyState shows its words and its one action', (tester) async {
    var tapped = false;
    await _show(
      tester,
      EmptyState(
        icon: Icons.inbox,
        message: 'Nothing yet',
        detail: 'Check back soon',
        action: FilledButton(onPressed: () => tapped = true, child: const Text('Offer')),
      ),
    );
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Check back soon'), findsOneWidget);
    await tester.tap(find.text('Offer'));
    expect(tapped, isTrue);
  });

  testWidgets('NotFoundScaffold has a way back and says what is missing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const NotFoundScaffold(message: 'Gone'),
    ));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Gone'), findsOneWidget);
  });

  testWidgets('InfoChip: strong facts use the brand color, map chips the panel color',
      (tester) async {
    Color fill(String label) => (tester
            .widget<DecoratedBox>(
              find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)).first,
            )
            .decoration as BoxDecoration)
        .color!;

    await _show(
      tester,
      const Column(children: [
        InfoChip(label: 'Verified', icon: Icons.verified, strong: true),
        InfoChip(label: 'Plain'),
        InfoChip(label: 'Map offline', onMap: true, maxLines: 1),
      ]),
    );
    final theme = buildTheme(Brightness.light);
    expect(fill('Verified'), theme.colorScheme.primaryContainer);
    expect(fill('Plain'), theme.colorScheme.surfaceContainerHighest);
    expect(fill('Map offline'), theme.extension<AppColors>()!.glass);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('AdvancedSection keeps its detail folded until tapped', (tester) async {
    await _show(
      tester,
      const AdvancedSection(subtitle: 'Radios and history', children: [Text('3 hops')]),
    );
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Radios and history'), findsOneWidget);
    expect(find.text('3 hops'), findsNothing);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('3 hops'), findsOneWidget);
    expect(tester.getSize(find.byType(ListTile).first).height, greaterThanOrEqualTo(48));
  });

  testWidgets('ResourceBadge still works from resource_sheet.dart', (tester) async {
    final verified = Resource(
      id: 'v',
      kind: ResourceKind.water,
      name: '',
      location: const LatLng(0, 0),
      lastObserved: DateTime.now(),
      organization: 'City of San Jose',
    );
    await _show(tester, ResourceBadge(resource: verified));
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(resourceMark(tester.element(find.byType(ResourceBadge)), verified), isNotNull);
  });

  testWidgets('FlatSkeletons trades the shimmer for a flat fade, still under reduce motion',
      (tester) async {
    late SkeletonizerConfigData data;
    Future<void> show({required bool still}) => tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: FlatSkeletons(
            child: Builder(builder: (context) {
              data = SkeletonizerConfig.maybeOf(context)!;
              return const SizedBox();
            }),
          ),
        ));

    await show(still: false);
    expect(data.resolveEffect(Brightness.light), isA<PulseEffect>());
    expect(data.resolveEffect(Brightness.dark), isA<PulseEffect>());
    expect(data.resolveEffect(Brightness.light), isNot(isA<ShimmerEffect>()));
    await show(still: true);
    expect(data.resolveEffect(Brightness.light), isA<SolidColorEffect>());
  });
}
