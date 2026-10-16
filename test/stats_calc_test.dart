import 'package:fc26flutter/models.dart';
import 'package:fc26flutter/stats_calc.dart';
import 'package:flutter_test/flutter_test.dart';

MatchItem match(int id, String h, int hg, String a, int ag,
        {List<MarkItem> marks = const [], int day = 1}) =>
    MatchItem(
      id: id,
      homeTeamName: h,
      awayTeamName: a,
      homeGoals: hg,
      awayGoals: ag,
      leagueName: 'L',
      matchDate: DateTime(2026, 10, day, 12, id),
      result: hg > ag ? 'HOME_WIN' : (hg < ag ? 'AWAY_WIN' : 'DRAW'),
      marks: marks,
    );

MarkItem mark(int id, String name, String team, double r) =>
    MarkItem(playerId: id, playerName: name, teamName: team, rating: r);

void main() {
  // Antonio: W (3-0 vs Ivan), W (2-1 at Marcos), D (1-1 vs Mix), L (0-2 vs Ivan), W (4-0 vs Mix)
  final matches = [
    match(5, 'Antonio', 4, 'Mix', 0, day: 5),
    match(1, 'Antonio', 3, 'Iván', 0, day: 1),
    match(2, 'Marcos', 1, 'Antonio', 2, day: 2),
    match(3, 'Antonio', 1, 'Mix', 1, day: 3),
    match(4, 'Iván', 2, 'Antonio', 0, day: 4),
  ];

  test('profile counts results, goals, clean sheets and streaks in order', () {
    final p = profileOf('Antonio', matches); // given out of order on purpose
    expect(p.results, ['W', 'W', 'D', 'L', 'W']);
    expect([p.played, p.wins, p.draws, p.losses], [5, 3, 1, 1]);
    expect([p.goalsFor, p.goalsAgainst], [10, 4]);
    expect(p.cleanSheets, 2);
    expect(p.unbeaten, 1);
    expect(p.longestUnbeaten, 3);
    expect(p.longestWinning, 2);
    expect(p.winRate, closeTo(0.6, 1e-9));
    expect(p.form(3), ['D', 'L', 'W']);
  });

  test('a team that did not play has an empty profile', () {
    expect(profileOf('Nadie', matches).played, 0);
  });

  test('formByTeam covers every team', () {
    final f = formByTeam(matches);
    expect(f.keys.toSet(), {'Antonio', 'Iván', 'Marcos', 'Mix'});
    expect(f['Iván'], ['L', 'W']);
  });

  test('records: biggest win, most goals, streaks', () {
    final r = computeRecords(matches);
    expect(r.biggestWin!.id, 5); // 4-0
    expect(r.mostGoals!.id, 5);
    expect(r.longestUnbeaten!.team, 'Antonio');
    expect(r.longestUnbeaten!.length, 3);
    expect(r.longestWinning!.length, 2);
  });

  test('MVPs and best averages', () {
    final withMarks = [
      match(1, 'Antonio', 1, 'Iván', 0, marks: [
        mark(10, 'Delantero', 'Antonio', 8.5),
        mark(11, 'Portero', 'Iván', 7.0),
      ]),
      match(2, 'Antonio', 2, 'Iván', 2, marks: [
        mark(10, 'Delantero', 'Antonio', 7.5),
        mark(11, 'Portero', 'Iván', 9.0),
      ]),
      match(3, 'Iván', 0, 'Antonio', 1, marks: [
        mark(10, 'Delantero', 'Antonio', 9.0),
        mark(12, 'Solo una vez', 'Iván', 8.0),
      ]),
    ];
    final r = computeRecords(withMarks);
    expect(r.mvps.first.playerName, 'Delantero');
    expect(r.mvps.first.count, 2);
    expect(r.mvps[1].playerName, 'Portero');
    // minimum 2 rated matches: "Solo una vez" is left out
    expect(r.bestAverages.map((a) => a.playerName), ['Delantero', 'Portero']);
    expect(r.bestAverages.first.average, closeTo((8.5 + 7.5 + 9.0) / 3, 1e-9));
  });

  test('pair counts ignore home/away', () {
    final c = pairCounts(matches);
    expect(c[pairKey('Antonio', 'Mix')], 2);
    expect(c[pairKey('Mix', 'Antonio')], 2);
    expect(c[pairKey('Antonio', 'Iván')], 2);
    expect(c[pairKey('Marcos', 'Antonio')], 1);
  });
}
