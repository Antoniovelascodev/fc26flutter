import 'package:fc26flutter/api.dart';
import 'package:fc26flutter/models.dart';
import 'package:fc26flutter/ratings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Player _player(int id) => Player.fromJson({
      'id': id,
      'shortName': 'P$id',
      'longName': 'Player $id',
      'positions': 'ST',
      'overall': 80,
      'potential': 80,
    });

void main() {
  testWidgets('switching teams while a squad is loading never duplicates players', (tester) async {
    // Demo mode (default in tests): one squad of 3 players for each of the teams 1, 2, 3.
    for (final team in [1, 2, 3]) {
      await tester.runAsync(() => Api.saveSquad(Squad(
            leagueId: 1,
            teamId: team,
            name: 'S$team',
            formation: '4-3-3',
            slots: {for (var i = 0; i < 3; i++) i: _player(team * 100 + i)},
          )));
    }

    final marks = <MatchMark>[];
    Widget card(int home, int away) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RatingsCard(
                key: ValueKey('$home-$away'),
                home: Team(id: home, name: 'T$home'),
                away: Team(id: away, name: 'T$away'),
                leagueId: 1,
                marks: marks,
                onChanged: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(card(1, 2));
    await tester.pumpWidget(card(1, 3)); // new teams chosen before the first load ended
    await tester.pumpWidget(card(2, 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(marks, isNotEmpty);
    final keys = marks.map((m) => '${m.teamId}:${m.player.id}').toList();
    expect(keys.toSet().length, keys.length, reason: 'a player appears twice');
    expect(marks.length, 6); // 3 players of team 2 + 3 of team 3 only
  });
}
