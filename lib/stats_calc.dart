import 'models.dart';

/// Pure calculations over a list of saved matches (no UI, easy to test).

DateTime _when(MatchItem m) => m.matchDate ?? DateTime.fromMillisecondsSinceEpoch(0);

/// Oldest first; the id breaks ties between matches saved at the same moment.
List<MatchItem> chronological(Iterable<MatchItem> matches) {
  final list = matches.toList();
  list.sort((a, b) {
    final c = _when(a).compareTo(_when(b));
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

/// W / D / L of [team] in [m], or null if the team did not play it.
String? resultFor(MatchItem m, String team) {
  final String? own;
  final int mine;
  final int theirs;
  if (m.homeTeamName == team) {
    own = team;
    mine = m.homeGoals;
    theirs = m.awayGoals;
  } else if (m.awayTeamName == team) {
    own = team;
    mine = m.awayGoals;
    theirs = m.homeGoals;
  } else {
    own = null;
    mine = 0;
    theirs = 0;
  }
  if (own == null) return null;
  return mine > theirs ? 'W' : (mine < theirs ? 'L' : 'D');
}

class TeamProfile {
  final String name;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int cleanSheets;

  /// Results oldest -> newest (W / D / L).
  final List<String> results;

  /// Matches in a row without losing, counting back from the latest match.
  final int unbeaten;
  final int longestUnbeaten;
  final int longestWinning;

  const TeamProfile({
    required this.name,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.cleanSheets,
    required this.results,
    required this.unbeaten,
    required this.longestUnbeaten,
    required this.longestWinning,
  });

  /// The last [n] results, oldest -> newest.
  List<String> form([int n = 5]) =>
      results.length <= n ? results : results.sublist(results.length - n);

  double get winRate => played == 0 ? 0 : wins / played;
  double get goalsForPerMatch => played == 0 ? 0 : goalsFor / played;
  double get goalsAgainstPerMatch => played == 0 ? 0 : goalsAgainst / played;
}

TeamProfile profileOf(String team, Iterable<MatchItem> matches) {
  var w = 0, d = 0, l = 0, gf = 0, ga = 0, clean = 0;
  final results = <String>[];
  var run = 0, bestUnbeaten = 0, winRun = 0, bestWin = 0;
  for (final m in chronological(matches)) {
    final r = resultFor(m, team);
    if (r == null) continue;
    final home = m.homeTeamName == team;
    final mine = home ? m.homeGoals : m.awayGoals;
    final theirs = home ? m.awayGoals : m.homeGoals;
    gf += mine;
    ga += theirs;
    if (theirs == 0) clean++;
    results.add(r);
    if (r == 'W') {
      w++;
    } else if (r == 'D') {
      d++;
    } else {
      l++;
    }
    run = r == 'L' ? 0 : run + 1;
    if (run > bestUnbeaten) bestUnbeaten = run;
    winRun = r == 'W' ? winRun + 1 : 0;
    if (winRun > bestWin) bestWin = winRun;
  }
  return TeamProfile(
    name: team,
    played: results.length,
    wins: w,
    draws: d,
    losses: l,
    goalsFor: gf,
    goalsAgainst: ga,
    cleanSheets: clean,
    results: results,
    unbeaten: run,
    longestUnbeaten: bestUnbeaten,
    longestWinning: bestWin,
  );
}

/// Last results of every team that appears in [matches] (oldest -> newest).
Map<String, List<String>> formByTeam(Iterable<MatchItem> matches, {int n = 5}) {
  final names = <String>{
    for (final m in matches) ...[m.homeTeamName, m.awayTeamName],
  };
  return {for (final t in names) t: profileOf(t, matches).form(n)};
}

class PlayerAward {
  final int playerId;
  final String playerName;
  final String teamName;
  final int count; // MVPs, or matches rated
  final double average; // average mark

  const PlayerAward(this.playerId, this.playerName, this.teamName, this.count, this.average);
}

class Records {
  final MatchItem? biggestWin;
  final MatchItem? mostGoals;
  final ({String team, int length})? longestUnbeaten;
  final ({String team, int length})? longestWinning;
  final List<PlayerAward> mvps;
  final List<PlayerAward> bestAverages;

  const Records({
    this.biggestWin,
    this.mostGoals,
    this.longestUnbeaten,
    this.longestWinning,
    this.mvps = const [],
    this.bestAverages = const [],
  });
}

Records computeRecords(List<MatchItem> matches, {int minRatedMatches = 2}) {
  MatchItem? biggest;
  MatchItem? most;
  for (final m in matches) {
    final diff = (m.homeGoals - m.awayGoals).abs();
    final total = m.homeGoals + m.awayGoals;
    if (diff > 0 &&
        (biggest == null ||
            diff > (biggest.homeGoals - biggest.awayGoals).abs() ||
            (diff == (biggest.homeGoals - biggest.awayGoals).abs() &&
                total > biggest.homeGoals + biggest.awayGoals))) {
      biggest = m;
    }
    if (total > 0 && (most == null || total > most.homeGoals + most.awayGoals)) {
      most = m;
    }
  }

  final teams = <String>{
    for (final m in matches) ...[m.homeTeamName, m.awayTeamName],
  };
  ({String team, int length})? unbeaten;
  ({String team, int length})? winning;
  for (final t in teams) {
    final p = profileOf(t, matches);
    if (p.longestUnbeaten > 0 && (unbeaten == null || p.longestUnbeaten > unbeaten.length)) {
      unbeaten = (team: t, length: p.longestUnbeaten);
    }
    if (p.longestWinning > 0 && (winning == null || p.longestWinning > winning.length)) {
      winning = (team: t, length: p.longestWinning);
    }
  }

  final mvpCount = <String, int>{};
  final mvpInfo = <String, MarkItem>{};
  final sums = <String, double>{};
  final rated = <String, int>{};
  for (final m in matches) {
    final mvp = m.mvp;
    if (mvp != null) {
      final key = '${mvp.playerId}:${mvp.teamName}';
      mvpCount[key] = (mvpCount[key] ?? 0) + 1;
      mvpInfo[key] = mvp;
    }
    for (final k in m.marks) {
      final key = '${k.playerId}:${k.teamName}';
      sums[key] = (sums[key] ?? 0) + k.rating;
      rated[key] = (rated[key] ?? 0) + 1;
      mvpInfo.putIfAbsent(key, () => k);
    }
  }
  PlayerAward award(String key, int count) {
    final info = mvpInfo[key]!;
    final n = rated[key] ?? 0;
    return PlayerAward(info.playerId, info.playerName, info.teamName, count,
        n == 0 ? 0 : (sums[key] ?? 0) / n);
  }

  final mvps = [for (final e in mvpCount.entries) award(e.key, e.value)]
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : b.average.compareTo(a.average);
    });
  final best = [
    for (final e in rated.entries)
      if (e.value >= minRatedMatches) award(e.key, e.value),
  ]..sort((a, b) => b.average.compareTo(a.average));

  return Records(
    biggestWin: biggest,
    mostGoals: most,
    longestUnbeaten: unbeaten,
    longestWinning: winning,
    mvps: mvps,
    bestAverages: best,
  );
}

/// How many matches each pair of teams has played (key: the two names, sorted).
Map<String, int> pairCounts(Iterable<MatchItem> matches) {
  final out = <String, int>{};
  for (final m in matches) {
    out.update(pairKey(m.homeTeamName, m.awayTeamName), (v) => v + 1, ifAbsent: () => 1);
  }
  return out;
}

String pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
