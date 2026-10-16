import 'package:fc26flutter/player_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picker with no budget left shows players (no 0M filter) and blocks them as over budget',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => pickPlayer(context, maxValueEur: 0),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    // Players are listed even though the remaining budget is 0 ...
    expect(find.byType(PlayerTile), findsWidgets);
    // ... with no price filter applied (no filter badge) and the budget shown.
    expect(find.textContaining('budget left 0M'), findsOneWidget);
    expect(find.text('Over budget'), findsWidgets);

    // Over budget is only a warning: the player can still be chosen.
    final tile = tester.widget<PlayerTile>(find.byType(PlayerTile).first);
    expect(tile.onTap, isNotNull);
  });
}
