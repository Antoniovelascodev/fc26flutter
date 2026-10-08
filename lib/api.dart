import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// true  -> fake in-memory data, no backend needed (to preview the UI).
/// false -> talk to the real Spring Boot API.
///
/// Switch without editing code:
///   flutter run -d chrome --dart-define=DEMO=false
const bool demoMode = bool.fromEnvironment('DEMO', defaultValue: true);

/// Base URL of the Spring Boot API (only used when demoMode is false).
///
/// - Android emulator: 10.0.2.2 is the host machine's localhost.
/// - Chrome / iOS simulator: localhost.
/// - Deployed API: pass it at run/build time:
///   --dart-define=API_URL=https://your-api.example.com/api
String get baseUrl {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) return override;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080/api';
  }
  return 'http://localhost:8080/api';
}

/// Incremented every time data changes so screens know they must reload.
final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
void notifyDataChanged() => dataVersion.value++;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class Api {
  static const _jsonHeaders = {'Content-Type': 'application/json; charset=utf-8'};
  static const _timeout = Duration(seconds: 10);

  static Future<void> _latency() =>
      Future.delayed(const Duration(milliseconds: 150));

  static dynamic _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException('Server error (${r.statusCode})');
    }
    if (r.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<dynamic> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
      return _decode(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Is the API running?');
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _jsonHeaders,
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(_timeout);
      return _decode(r);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Is the API running?');
    }
  }

  // ---- Teams ----
  static Future<List<Team>> teams() async {
    if (demoMode) {
      await _latency();
      return List<Team>.from(_Demo.teams);
    }
    final data = await _get('/teams') as List;
    return data.map((e) => Team.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createTeam(String name) async {
    if (demoMode) {
      await _latency();
      if (!_Demo.teams.any((t) => t.name == name)) {
        _Demo.teams.add(Team(id: _Demo.teams.length + 1, name: name));
      }
      return;
    }
    await _post('/teams', {'name': name});
  }

  // ---- Leagues ----
  static Future<List<League>> leagues() async {
    if (demoMode) {
      await _latency();
      return List<League>.from(_Demo.leagues);
    }
    final data = await _get('/leagues') as List;
    return data.map((e) => League.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createLeague(String name) async {
    if (demoMode) {
      await _latency();
      _Demo.leagues.add(League(id: _Demo.leagues.length + 1, name: name));
      return;
    }
    await _post('/leagues', {'name': name, 'description': ''});
  }

  // ---- Matches ----
  static Future<void> createMatch({
    required int homeTeamId,
    required int awayTeamId,
    required int homeGoals,
    required int awayGoals,
    required int leagueId,
  }) async {
    if (demoMode) {
      await _latency();
      _Demo.matches.add(_DemoMatch(
        id: _Demo.nextMatchId++,
        homeId: homeTeamId,
        awayId: awayTeamId,
        homeGoals: homeGoals,
        awayGoals: awayGoals,
        leagueId: leagueId,
        date: DateTime.now(),
      ));
      return;
    }
    await _post('/matches', {
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'leagueId': leagueId,
    });
  }

  static Future<List<MatchItem>> matchesByLeague(int leagueId) async {
    if (demoMode) {
      await _latency();
      final list = _Demo.matches
          .where((m) => m.leagueId == leagueId)
          .map(_Demo.toItem)
          .toList();
      list.sort((a, b) =>
          (b.matchDate ?? DateTime(0)).compareTo(a.matchDate ?? DateTime(0)));
      return list;
    }
    final data = await _get('/matches/league/$leagueId') as List;
    final list =
        data.map((e) => MatchItem.fromJson(e as Map<String, dynamic>)).toList();
    list.sort((a, b) =>
        (b.matchDate ?? DateTime(0)).compareTo(a.matchDate ?? DateTime(0)));
    return list;
  }

  static Future<HeadToHead> headToHead(int team1Id, int team2Id) async {
    if (demoMode) {
      await _latency();
      return _Demo.headToHead(team1Id, team2Id);
    }
    final data = await _get('/matches/h2h/$team1Id/$team2Id');
    return HeadToHead.fromJson(data as Map<String, dynamic>);
  }

  // ---- MegaLeague ----
  static Future<List<RankingEntry>> ranking() async {
    if (demoMode) {
      await _latency();
      return _Demo.ranking();
    }
    final data = await _get('/mega-league/ranking') as List;
    return data.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

// ---------------------------------------------------------------------------
// Demo mode: in-memory data that mimics what the backend would return.
// ---------------------------------------------------------------------------

class _DemoMatch {
  final int id;
  final int homeId;
  final int awayId;
  final int homeGoals;
  final int awayGoals;
  final int leagueId;
  final DateTime date;

  _DemoMatch({
    required this.id,
    required this.homeId,
    required this.awayId,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueId,
    required this.date,
  });
}

class _Demo {
  static final List<Team> teams = [
    Team(id: 1, name: 'Antonio'),
    Team(id: 2, name: 'Iván'),
    Team(id: 3, name: 'Marcos'),
    Team(id: 4, name: 'Mix'),
  ];

  static final List<League> leagues = [League(id: 1, name: 'League 1')];

  static int nextMatchId = 6;

  static final List<_DemoMatch> matches = [
    _DemoMatch(id: 1, homeId: 1, awayId: 2, homeGoals: 3, awayGoals: 1, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 5))),
    _DemoMatch(id: 2, homeId: 3, awayId: 4, homeGoals: 2, awayGoals: 2, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 4))),
    _DemoMatch(id: 3, homeId: 2, awayId: 3, homeGoals: 0, awayGoals: 1, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 3))),
    _DemoMatch(id: 4, homeId: 4, awayId: 1, homeGoals: 1, awayGoals: 4, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 2))),
    _DemoMatch(id: 5, homeId: 2, awayId: 1, homeGoals: 2, awayGoals: 2, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 1))),
  ];

  static String _teamName(int id) => teams.firstWhere((t) => t.id == id).name;

  static String _leagueName(int id) =>
      leagues.firstWhere((l) => l.id == id).name;

  static MatchItem toItem(_DemoMatch m) {
    final result = m.homeGoals > m.awayGoals
        ? 'HOME_WIN'
        : (m.awayGoals > m.homeGoals ? 'AWAY_WIN' : 'DRAW');
    return MatchItem(
      id: m.id,
      homeTeamName: _teamName(m.homeId),
      awayTeamName: _teamName(m.awayId),
      homeGoals: m.homeGoals,
      awayGoals: m.awayGoals,
      leagueName: _leagueName(m.leagueId),
      matchDate: m.date,
      result: result,
    );
  }

  static List<RankingEntry> ranking() {
    final out = <RankingEntry>[];
    for (final t in teams) {
      int played = 0, wins = 0, draws = 0, losses = 0, gf = 0, ga = 0;
      for (final m in matches) {
        int own;
        int opp;
        if (m.homeId == t.id) {
          own = m.homeGoals;
          opp = m.awayGoals;
        } else if (m.awayId == t.id) {
          own = m.awayGoals;
          opp = m.homeGoals;
        } else {
          continue;
        }
        played++;
        gf += own;
        ga += opp;
        if (own > opp) {
          wins++;
        } else if (own < opp) {
          losses++;
        } else {
          draws++;
        }
      }
      if (played == 0) continue; // like the backend: only teams that played
      out.add(RankingEntry(
        teamName: t.name,
        points: wins * 3 + draws,
        matchesPlayed: played,
        wins: wins,
        draws: draws,
        losses: losses,
        goalsFor: gf,
        goalsAgainst: ga,
        goalDifference: gf - ga,
      ));
    }
    out.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return out;
  }

  static HeadToHead headToHead(int t1, int t2) {
    int w1 = 0, w2 = 0, draws = 0, g1 = 0, g2 = 0;
    final list = <_DemoMatch>[];
    for (final m in matches) {
      final direct = m.homeId == t1 && m.awayId == t2;
      final reverse = m.homeId == t2 && m.awayId == t1;
      if (!direct && !reverse) continue;
      list.add(m);
      final goals1 = direct ? m.homeGoals : m.awayGoals;
      final goals2 = direct ? m.awayGoals : m.homeGoals;
      g1 += goals1;
      g2 += goals2;
      if (goals1 > goals2) {
        w1++;
      } else if (goals2 > goals1) {
        w2++;
      } else {
        draws++;
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return HeadToHead(
      team1Name: _teamName(t1),
      team2Name: _teamName(t2),
      team1Wins: w1,
      team2Wins: w2,
      draws: draws,
      team1GoalsFor: g1,
      team2GoalsFor: g2,
      matches: list.map(toItem).toList(),
    );
  }
}
