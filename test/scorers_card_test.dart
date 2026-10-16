import 'package:fc26flutter/models.dart';
import 'package:fc26flutter/scorers_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('own goal counts for the team and nobody gets it', (tester) async {
    final home = Team(id: 1, name: 'Antonio');
    final away = Team(id: 2, name: 'Iván');
    final scorers = <ScorerInput>[];
    final ownGoals = <int, int>{};
    var changes = 0;

    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return ScorersCard(
              home: home,
              away: away,
              homeGoals: 2,
              awayGoals: 0,
              leagueId: 1,
              scorers: scorers,
              ownGoals: ownGoals,
              onChanged: () {
                changes++;
                rebuild(() {});
              },
            );
          }),
        ),
      ),
    ));

    expect(find.text('Who scored?'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Own goal'), findsOneWidget);

    await tester.tap(find.text('Own goal'));
    await tester.pump();
    expect(ownGoals[1], 1);
    expect(scorers, isEmpty);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Own goal (by the opponent)'), findsOneWidget);

    // + on the own goal row reaches 2/2 and then the add buttons disappear.
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pump();
    expect(ownGoals[1], 2);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Add scorer'), findsNothing);
    expect(changes, 2);

    // - twice removes it.
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pump();
    expect(ownGoals.containsKey(1), isFalse);
    expect(find.text('0 / 2'), findsOneWidget);
  });
}
