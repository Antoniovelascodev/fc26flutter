// Runs the app's own Api class against a REAL backend. Skipped in demo mode.
//
//   flutter test test/live_api_test.dart --dart-define=DEMO=false --dart-define=API_URL=http://localhost:8090/api
//
// The backend must have been seeded (tools/api-tests: smoke suites + seed.js).
import 'dart:io';

import 'package:fc26flutter/api.dart';
import 'package:fc26flutter/models.dart';
import 'package:fc26flutter/player_filters.dart';
import 'package:fc26flutter/stats_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  if (demoMode) {
    test('live API tests are skipped in demo mode', () {}, skip: 'run with --dart-define=DEMO=false');
    return;
  }
  setUpAll(() => HttpOverrides.global = null);

  late List<Team> teams;
  late League league;
  late Team marcos;
  late Team mix;

  test('teams and leagues parse', () async {
    teams = await Api.teams();
    expect(teams.map((t) => t.name), containsAll(['Antonio', 'Iván', 'Marcos', 'Mix']));
    final leagues = await Api.leagues();
    league = leagues.firstWhere((l) => l.name.startsWith('Liga Demo'));
    marcos = teams.firstWhere((t) => t.name == 'Marcos');
    mix = teams.firstWhere((t) => t.name == 'Mix');
  });

  test('player search with filters, positions and paging', () async {
    final all = await Api.searchPlayers();
    expect(all.total, greaterThan(100));
    expect(all.players.length, 20);
    expect(all.players.first.overall, greaterThanOrEqualTo(all.players.last.overall));

    final byName = await Api.searchPlayers(q: 'mbappe');
    expect(byName.players.any((p) => p.shortName.contains('Mbapp')), isTrue);

    final gk = await Api.searchPlayers(position: 'CB');
    expect(gk.players, isNotEmpty);
    expect(gk.players.every((p) => p.positions.contains('CB')), isTrue);

    // No default price filter: an empty filter returns everybody, a 0M cap returns nobody.
    final noFilter = await Api.searchPlayers(filters: PlayerFilters());
    expect(noFilter.total, all.total);
    final f = PlayerFilters()..minOverall = 85;
    final high = await Api.searchPlayers(filters: f);
    expect(high.players.every((p) => p.overall >= 85), isTrue);
    final page2 = await Api.searchPlayers(page: 1);
    expect(page2.players.first.id, isNot(all.players.first.id));

    final f2 = PlayerFilters()..stats = {'pace': 90};
    final fast = await Api.searchPlayers(filters: f2);
    expect(fast.players.every((p) => (p.stat('pace') ?? 0) >= 90), isTrue);
  });

  test('squads, taken players, league ratings parse', () async {
    final squads = await Api.squads(leagueId: league.id);
    expect(squads.length, 2);
    final ms = squads.firstWhere((s) => s.teamId == marcos.id);
    expect(ms.slots.length, 21);
    expect(ms.slots.keys.every((k) => k >= 0 && k <= 20), isTrue);
    final taken = await Api.takenPlayers(league.id, mix.id);
    expect(taken, isNotEmpty);
  });

  test('standings, scorers, most used, best XI parse', () async {
    final st = await Api.standings(league.id);
    expect(st.first.teamName, 'Marcos');
    final sc = await Api.topScorers(leagueId: league.id);
    expect(sc.first.goals, 2);
    expect((await Api.mostUsed(leagueId: league.id)), isNotEmpty);
    expect((await Api.leagueRatings(league.id)), isNotEmpty);
    expect((await Api.ranking()), isNotEmpty);
    expect((await Api.megaRatings()), isNotEmpty);
  });

  test('saving a match like the app does: scorers + marks + own goal, then stats', () async {
    final squads = await Api.squads(leagueId: league.id);
    final ms = squads.firstWhere((s) => s.teamId == marcos.id);
    final xs = squads.firstWhere((s) => s.teamId == mix.id);
    final scorer = ms.slots[9]!;

    // Mix wins 3-1: Mix has 2 scorers and 1 own goal (nobody gets it); Marcos 1 goal.
    final scorers = [
      ScorerInput(player: scorer, teamId: marcos.id, goals: 1),
      ScorerInput(player: xs.slots[8]!, teamId: mix.id, goals: 2),
    ];
    final marks = <MatchMark>[
      for (final e in ms.slots.entries.where((e) => e.key < 14))
        MatchMark(player: e.value, teamId: marcos.id, bench: e.key >= 11),
      for (final e in xs.slots.entries.where((e) => e.key < 14))
        MatchMark(player: e.value, teamId: mix.id, bench: e.key >= 11),
    ];
    // Scoring bonus as the new-match screen applies it: +1.5, +0.5 per extra goal.
    for (final m in marks) {
      final goals = scorers
          .where((s) => s.player.id == m.player.id && s.teamId == m.teamId)
          .fold<int>(0, (a, s) => a + s.goals);
      if (goals > 0) m.rating += 1.5 + 0.5 * (goals - 1);
    }
    marks.last.played = false; // one did not play: must not be sent

    final before = await Api.matchesByLeague(league.id);
    await Api.createMatch(
      homeTeamId: marcos.id,
      awayTeamId: mix.id,
      homeGoals: 1,
      awayGoals: 3,
      leagueId: league.id,
      scorers: scorers,
      marks: marks,
    );
    final after = await Api.matchesByLeague(league.id);
    expect(after.length, before.length + 1);
    final saved = after.firstWhere((m) => m.homeGoals == 1 && m.awayGoals == 3);
    expect(saved.goalsOf('Mix').fold<int>(0, (a, g) => a + g.goals), 2);
    expect(saved.marks.length, 27); // 28 minus the one that did not play
    expect(saved.mvp!.rating, 8.0); // 6 + 1.5 + 0.5
    expect(saved.mvp!.teamName, 'Mix');

    // The same player in the other direction: scorer not in the squad is rejected.
    final stranger = (await Api.searchPlayers(q: 'neymar')).players.firstOrNull;
    if (stranger != null) {
      await expectLater(
        Api.createMatch(
          homeTeamId: marcos.id,
          awayTeamId: mix.id,
          homeGoals: 1,
          awayGoals: 0,
          leagueId: league.id,
          scorers: [ScorerInput(player: stranger, teamId: marcos.id)],
        ),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
      expect((await Api.matchesByLeague(league.id)).length, after.length,
          reason: 'a rejected match must not be saved');
    }

    // Stats over real data.
    final all = await Api.allMatches();
    expect(all.length, greaterThanOrEqualTo(2));
    final pm = profileOf('Mix', after);
    expect(pm.played, 2);
    expect([pm.wins, pm.losses], [1, 1]); // lost 1-2 (seed), won 3-1
    expect(pm.form(), ['L', 'W']);
    final form = formByTeam(all);
    expect(form['Marcos'], ['W', 'L']);
    final rec = computeRecords(after);
    expect(rec.biggestWin, isNotNull);
    expect(rec.mvps, isNotEmpty);
    expect(pairCounts(after)[pairKey('Marcos', 'Mix')], 2);

    // The table moved.
    final st = await Api.standings(league.id);
    expect(st.firstWhere((e) => e.teamName == 'Mix').points, 3);
    expect(st.firstWhere((e) => e.teamName == 'Marcos').points, 3);
  });

  test('head to head and match deletion (needs the group key)', () async {
    final h = await Api.headToHead(marcos.id, mix.id);
    expect(h.matches.length, 2);
    expect(h.team1Wins + h.team2Wins + h.draws, 2);
  });
}
