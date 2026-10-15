import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'player_filters.dart';

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

/// true while a request is taking suspiciously long (the free server is waking up).
final ValueNotifier<bool> waking = ValueNotifier<bool>(false);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class Api {
  // Long enough for a sleeping free server (it can take about a minute).
  static const _timeout = Duration(seconds: 75);
  static const _prefsKey = 'api_key';

  // ---- Shared access key (sent as X-API-Key on every request) ----
  static String _apiKey = '';

  static String get apiKey => _apiKey;
  static bool get hasKey => _apiKey.isNotEmpty;

  /// Call once at startup, before runApp.
  static Future<void> loadKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_prefsKey) ?? '';
      _adminKey = prefs.getString('admin_key') ?? '';
      final raw = prefs.getString('team_pins');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) => _pins[int.parse(k)] = v as String);
      }
    } catch (_) {
      _apiKey = '';
    }
  }

  static Future<void> saveKey(String key) async {
    _apiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _apiKey);
    } catch (_) {
      // The key still works for this session.
    }
  }

  // ---- Owner-only admin key (backups, imports) ----
  static String _adminKey = '';

  static String get adminKey => _adminKey;

  static Future<void> saveAdminKey(String key) async {
    _adminKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_key', _adminKey);
    } catch (_) {
      // Still works for this session.
    }
  }

  // ---- Team PINs known on this device (team id -> PIN) ----
  static final Map<int, String> _pins = {};

  static String? pinOf(int teamId) => _pins[teamId];

  static Future<void> _savePins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('team_pins', jsonEncode(_pins.map((k, v) => MapEntry('$k', v))));
    } catch (_) {
      // Still works for this session.
    }
  }

  /// Sets the PIN of a team (or changes it when [currentPin] is given) and remembers it.
  static Future<void> setTeamPin(int teamId, String newPin, {String? currentPin}) async {
    if (!demoMode) {
      await _post('/teams/$teamId/pin', {'currentPin': currentPin, 'newPin': newPin});
    }
    _pins[teamId] = newPin;
    await _savePins();
  }

  /// Checks the PIN with the server and remembers it on this device if it is right.
  static Future<void> unlockTeam(int teamId, String pin) async {
    if (!demoMode) {
      await _post('/teams/$teamId/pin/check', {'pin': pin});
    }
    _pins[teamId] = pin;
    await _savePins();
  }

  static Future<void> forgetTeamPin(int teamId) async {
    _pins.remove(teamId);
    await _savePins();
  }

  /// Makes every squad of the league visible to everyone.
  static Future<void> revealLeague(int leagueId) async {
    if (demoMode) return;
    await _post('/leagues/$leagueId/reveal', {});
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
        if (_adminKey.isNotEmpty) 'X-Admin-Key': _adminKey,
        if (_pins.isNotEmpty)
          'X-Team-Pins': _pins.entries.map((e) => '${e.key}:${e.value}').join(','),
      };

  static Future<void> _latency() =>
      Future.delayed(const Duration(milliseconds: 150));

  static dynamic _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      if (r.statusCode == 401) {
        throw ApiException(
            'Access key missing or wrong. Tap the key icon (top right) to set it.');
      }
      String? message;
      try {
        final body = jsonDecode(utf8.decode(r.bodyBytes));
        if (body is Map && body['message'] is String) {
          message = body['message'] as String;
        }
      } catch (_) {
        // Not JSON: use the generic message below.
      }
      if (message == null || message.trim().isEmpty) {
        message = 'Server error (${r.statusCode})';
      }
      throw ApiException(message);
    }
    if (r.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// Runs one HTTP call. If it takes more than a few seconds the free server is
  /// probably waking up, so [waking] turns on and the UI explains the wait.
  static Future<dynamic> _send(Future<http.Response> Function() call) async {
    final timer = Timer(const Duration(seconds: 4), () => waking.value = true);
    try {
      return _decode(await call().timeout(_timeout));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the server. Is the API running?');
    } finally {
      timer.cancel();
      waking.value = false;
    }
  }

  static Future<dynamic> _get(String path) =>
      _send(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers));

  static Future<dynamic> _post(String path, Map<String, dynamic> body) =>
      _send(() => http.post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: utf8.encode(jsonEncode(body)),
          ));

  static Future<dynamic> _put(String path, Map<String, dynamic> body) =>
      _send(() => http.put(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: utf8.encode(jsonEncode(body)),
          ));

  static Future<dynamic> _delete(String path) =>
      _send(() => http.delete(Uri.parse('$baseUrl$path'), headers: _headers));

  /// Wakes the server up as soon as the app opens, so the first real request
  /// does not have to wait for it.
  static Future<void> warmUp() async {
    if (demoMode) return;
    try {
      await _get('/health');
    } catch (_) {
      // Real requests report their own errors.
    }
  }

  /// All data as pretty JSON text (needs the access key).
  static Future<String> exportBackup() async {
    if (demoMode) {
      await _latency();
      return '{"demo": true}';
    }
    final data = await _get('/admin/export');
    return const JsonEncoder.withIndent('  ').convert(data);
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

  static Future<void> createLeague(String name, {int? budgetMillions}) async {
    if (demoMode) {
      await _latency();
      _Demo.leagues.add(League(
          id: _Demo.leagues.length + 1, name: name, budgetMillions: budgetMillions));
      return;
    }
    await _post('/leagues', {
      'name': name,
      'description': '',
      'budgetMillions': ?budgetMillions,
    });
  }

  /// Sets (or removes, with null) the maximum value of a squad in the league.
  static Future<void> setLeagueBudget(League league, int? millions) async {
    if (demoMode) {
      await _latency();
      final i = _Demo.leagues.indexWhere((l) => l.id == league.id);
      if (i >= 0) {
        _Demo.leagues[i] =
            League(id: league.id, name: league.name, budgetMillions: millions);
      }
      return;
    }
    await _put('/leagues/${league.id}', {
      'name': league.name,
      'description': league.description ?? '',
      'budgetMillions': millions,
    });
  }

  /// How many matches, squads and ratings deleting the league would remove.
  static Future<({int matches, int squads, int ratings})> leagueImpact(int id) async {
    if (demoMode) {
      await _latency();
      return (
        matches: _Demo.matches.where((m) => m.leagueId == id).length,
        squads: _Demo.squads.where((s) => s.leagueId == id).length,
        ratings: 0,
      );
    }
    final data = await _get('/leagues/$id/impact') as Map<String, dynamic>;
    return (
      matches: (data['matches'] as num).toInt(),
      squads: (data['squads'] as num).toInt(),
      ratings: (data['ratings'] as num).toInt(),
    );
  }

  /// Deletes the league and everything in it (matches, scorers, squads, ratings).
  static Future<void> deleteLeague(int id) async {
    if (demoMode) {
      await _latency();
      _Demo.matches.removeWhere((m) => m.leagueId == id);
      _Demo.squads.removeWhere((s) => s.leagueId == id);
      _Demo.leagues.removeWhere((l) => l.id == id);
      return;
    }
    await _delete('/leagues/$id?cascade=true');
  }

  // ---- Matches ----
  static Future<void> createMatch({
    required int homeTeamId,
    required int awayTeamId,
    required int homeGoals,
    required int awayGoals,
    required int leagueId,
    List<ScorerInput> scorers = const [],
    List<MatchMark> marks = const [],
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
        goals: [
          for (final g in scorers)
            GoalItem(
              playerId: g.player.id,
              playerName: g.player.shortName,
              teamName: _Demo._teamName(g.teamId),
              goals: g.goals,
            ),
        ],
      ));
      return;
    }
    await _post('/matches', {
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'leagueId': leagueId,
      if (scorers.isNotEmpty)
        'goals': [
          for (final g in scorers)
            {'playerId': g.player.id, 'teamId': g.teamId, 'goals': g.goals},
        ],
      if (marks.where((m) => m.played).isNotEmpty)
        'ratings': [
          for (final m in marks.where((m) => m.played))
            {'playerId': m.player.id, 'teamId': m.teamId, 'rating': m.rating},
        ],
    });
  }

  static Future<void> deleteMatch(int id) async {
    if (demoMode) {
      await _latency();
      _Demo.matches.removeWhere((m) => m.id == id);
      return;
    }
    await _delete('/matches/$id');
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

  // ---- Players ----
  static Future<PlayerPage> searchPlayers({
    String q = '',
    String position = '',
    PlayerFilters? filters,
    int page = 0,
  }) async {
    final f = filters ?? PlayerFilters();
    if (demoMode) {
      await _latency();
      return _Demo.searchPlayers(q, position, f, page);
    }
    final query = Uri(queryParameters: {
      'q': q,
      'position': position,
      ...f.toQuery(),
      'page': '$page',
      'size': '20',
    }).query;
    final data = await _get('/players?$query');
    return PlayerPage.fromJson(data as Map<String, dynamic>);
  }

  /// Real leagues that have players (for the filter dropdown).
  static Future<List<String>> playerLeagues() async {
    if (demoMode) return ['Demo League'];
    final data = await _get('/players/leagues') as List;
    return data.map((e) => e as String).toList();
  }

  // ---- Squads ----
  static Future<List<Squad>> squads({int? leagueId, int? teamId}) async {
    if (demoMode) {
      await _latency();
      return _Demo.squads
          .where((s) =>
              (leagueId == null || s.leagueId == leagueId) &&
              (teamId == null || s.teamId == teamId))
          .toList();
    }
    final params = <String, String>{
      if (leagueId != null) 'leagueId': '$leagueId',
      if (teamId != null) 'teamId': '$teamId',
    };
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final data = await _get('/squads$query') as List;
    return data.map((e) => Squad.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates the squad (id == null) or replaces an existing one.
  static Future<Squad> saveSquad(Squad squad) async {
    if (demoMode) {
      await _latency();
      return _Demo.saveSquad(squad);
    }
    final body = {
      'leagueId': squad.leagueId,
      'teamId': squad.teamId,
      'name': squad.name,
      'formation': squad.formation,
      'active': squad.active,
      'slots': [
        for (final e in squad.slots.entries) {'slot': e.key, 'playerId': e.value.id},
      ],
    };
    final data = squad.id == null
        ? await _post('/squads', body)
        : await _put('/squads/${squad.id}', body);
    return Squad.fromJson(data as Map<String, dynamic>);
  }

  /// Players the other teams already have in this league (they cannot be chosen again).
  static Future<Set<int>> takenPlayers(int leagueId, int teamId) async {
    if (demoMode) return {};
    final data = await _get('/squads/taken?leagueId=$leagueId&teamId=$teamId') as List;
    return data.map((e) => (e as num).toInt()).toSet();
  }

  /// Corrects the value of a player (euros). It also protects it from the next CSV import.
  static Future<void> setPlayerValue(int playerId, int valueEur) async {
    if (demoMode) {
      await _latency();
      return;
    }
    await _put('/players/$playerId/value', {'valueEur': valueEur});
  }

  static Future<void> deleteSquad(int id) async {
    if (demoMode) {
      await _latency();
      _Demo.squads.removeWhere((s) => s.id == id);
      return;
    }
    await _delete('/squads/$id');
  }

  // ---- League stats ----
  static Future<List<RankingEntry>> standings(int leagueId) async {
    if (demoMode) {
      await _latency();
      return _Demo.ranking(leagueId: leagueId);
    }
    final data = await _get('/leagues/$leagueId/standings') as List;
    return data.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Top scorers of one league, or of all leagues when [leagueId] is null.
  static Future<List<ScorerRow>> topScorers({int? leagueId}) async {
    if (demoMode) {
      await _latency();
      return _Demo.topScorers(leagueId);
    }
    final path = leagueId == null ? '/stats/top-scorers' : '/leagues/$leagueId/top-scorers';
    final data = await _get(path) as List;
    return data.map((e) => ScorerRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<MostUsedRow>> mostUsed({int? leagueId}) async {
    if (demoMode) {
      await _latency();
      return const [];
    }
    final data = await _get(leagueId == null
        ? '/stats/most-used'
        : '/stats/most-used?leagueId=$leagueId') as List;
    return data.map((e) => MostUsedRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Ratings (best XI) ----
  static Future<List<RatingRow>> leagueRatings(int leagueId) async {
    if (demoMode) {
      await _latency();
      return _Demo.leagueRatings(leagueId);
    }
    final data = await _get('/leagues/$leagueId/ratings') as List;
    return data.map((e) => RatingRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [rating] null removes the rating.
  static Future<void> rate(int leagueId, int playerId, double? rating) async {
    if (demoMode) {
      await _latency();
      _Demo.rate(leagueId, playerId, rating);
      return;
    }
    if (rating == null) {
      await _delete('/leagues/$leagueId/ratings/$playerId');
    } else {
      await _put('/leagues/$leagueId/ratings', {'playerId': playerId, 'rating': rating});
    }
  }

  static Future<List<RatingRow>> megaRatings() async {
    if (demoMode) {
      await _latency();
      return _Demo.megaRatings();
    }
    final data = await _get('/mega-league/ratings') as List;
    return data.map((e) => RatingRow.fromJson(e as Map<String, dynamic>)).toList();
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
  final List<GoalItem> goals;

  _DemoMatch({
    required this.id,
    required this.homeId,
    required this.awayId,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueId,
    required this.date,
    this.goals = const [],
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

  static final List<Squad> squads = [];
  static int _nextSquadId = 1;

  static final List<Player> players = _makePlayers();

  static List<Player> _makePlayers() {
    const positions = ['GK', 'CB', 'CB', 'LB', 'RB', 'CDM', 'CM', 'CAM', 'LW', 'RW', 'ST'];
    const surnames = [
      'Demo', 'Ejemplo', 'Prueba', 'Muestra', 'Test', 'Falso', 'Gris', 'Hueco', 'Juguete', 'Nulo',
    ];
    final out = <Player>[];
    var id = 1;
    for (var round = 0; round < 4; round++) {
      for (var i = 0; i < positions.length; i++) {
        final ovr = 90 - round * 5 - (i % 4);
        final surname = surnames[(i * 3 + round) % surnames.length];
        final isGk = positions[i] == 'GK';
        out.add(Player(
          id: id,
          shortName: '${String.fromCharCode(65 + i)}. $surname',
          longName: 'Player $id $surname',
          positions: positions[i],
          overall: ovr,
          potential: ovr + 2,
          valueEur: ovr * ovr * 3000,
          age: 20 + (i * 2 + round) % 14,
          clubName: 'Demo FC',
          leagueName: 'Demo League',
          nationalityName: 'Spain',
          pace: ovr - 3,
          shooting: ovr - 5,
          passing: ovr - 2,
          dribbling: ovr - 4,
          defending: ovr - 20,
          physic: ovr - 6,
          gkDiving: isGk ? ovr : null,
          gkHandling: isGk ? ovr - 2 : null,
          gkKicking: isGk ? ovr - 4 : null,
          gkReflexes: isGk ? ovr + 1 : null,
          gkSpeed: isGk ? 40 : null,
          gkPositioning: isGk ? ovr - 1 : null,
          detail: {
            for (final s in kStats)
              if (isGk == (s.group == 'Goalkeeping'))
                s.key: (ovr - 14 + ((i * 7 + s.key.length * 3 + round * 5) % 17)).clamp(25, 99),
          },
        ));
        id++;
      }
    }
    return out;
  }

  static PlayerPage searchPlayers(String q, String position, PlayerFilters f, int page) {
    final text = q.toLowerCase().trim();
    final sort = f.sort;
    final list = players.where((p) {
      if (position.isNotEmpty && !p.canPlay(position)) return false;
      if (f.minOverall != null && p.overall < f.minOverall!) return false;
      if (f.maxOverall != null && p.overall > f.maxOverall!) return false;
      if (f.maxValueM != null && (p.valueEur ?? 0) > f.maxValueM! * 1000000) return false;
      if (f.minValueM != null && (p.valueEur ?? 0) < f.minValueM! * 1000000) return false;
      return text.isEmpty ||
          p.shortName.toLowerCase().contains(text) ||
          p.longName.toLowerCase().contains(text);
    }).toList();
    list.sort((a, b) {
      final c = sort == 'value'
          ? (b.valueEur ?? 0).compareTo(a.valueEur ?? 0)
          : b.overall.compareTo(a.overall);
      return f.ascending ? -c : c;
    });
    final start = page * 20;
    final end = (start + 20).clamp(0, list.length);
    return PlayerPage(
      players: start >= list.length ? [] : list.sublist(start, end),
      hasNext: end < list.length,
      total: list.length,
    );
  }

  static final Map<String, double> _ratings = {};

  static void rate(int leagueId, int playerId, double? rating) {
    final key = '$leagueId/$playerId';
    if (rating == null) {
      _ratings.remove(key);
    } else {
      _ratings[key] = rating;
    }
  }

  static List<ScorerRow> topScorers(int? leagueId) {
    final totals = <String, ScorerRow>{};
    for (final m in matches) {
      if (leagueId != null && m.leagueId != leagueId) continue;
      for (final g in m.goals) {
        final player = players.firstWhere((p) => p.id == g.playerId);
        final key = '${g.playerId}/${g.teamName}';
        final old = totals[key];
        totals[key] = ScorerRow(
            player: player, teamName: g.teamName, goals: (old?.goals ?? 0) + g.goals);
      }
    }
    final list = totals.values.toList()..sort((a, b) => b.goals.compareTo(a.goals));
    return list;
  }

  static List<RatingRow> leagueRatings(int leagueId) {
    final ids = <int>{};
    final teamsOf = <int, Set<String>>{};
    for (final s in squads.where((s) => s.leagueId == leagueId)) {
      for (final p in s.slots.values) {
        ids.add(p.id);
        (teamsOf[p.id] ??= {}).add(s.teamName);
      }
    }
    final rows = [
      for (final p in players.where((p) => ids.contains(p.id)))
        RatingRow(
          player: p,
          rating: _ratings['$leagueId/${p.id}'],
          ratedIn: _ratings.containsKey('$leagueId/${p.id}') ? 1 : 0,
          teams: (teamsOf[p.id] ?? {}).toList(),
        ),
    ];
    rows.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    return rows;
  }

  static List<RatingRow> megaRatings() {
    final sums = <int, double>{};
    final counts = <int, int>{};
    _ratings.forEach((key, value) {
      final id = int.parse(key.split('/')[1]);
      sums[id] = (sums[id] ?? 0) + value;
      counts[id] = (counts[id] ?? 0) + 1;
    });
    final rows = [
      for (final id in sums.keys)
        RatingRow(
          player: players.firstWhere((p) => p.id == id),
          rating: sums[id]! / counts[id]!,
          ratedIn: counts[id]!,
          teams: const [],
        ),
    ];
    rows.sort((a, b) => b.rating!.compareTo(a.rating!));
    return rows;
  }

  static Squad saveSquad(Squad s) {
    final hasOther = squads.any(
        (q) => q.leagueId == s.leagueId && q.teamId == s.teamId && q.id != s.id);
    final saved = Squad(
      id: s.id ?? _nextSquadId++,
      leagueId: s.leagueId,
      teamId: s.teamId,
      teamName: _teamName(s.teamId),
      leagueName: _leagueName(s.leagueId),
      name: s.name,
      formation: s.formation,
      active: s.active || !hasOther,
      slots: Map<int, Player>.from(s.slots),
    );
    squads.removeWhere((q) => q.id == saved.id);
    if (saved.active) {
      for (final q in squads) {
        if (q.leagueId == saved.leagueId && q.teamId == saved.teamId) q.active = false;
      }
    }
    squads.add(saved);
    return saved;
  }

  static final List<_DemoMatch> matches = [
    _DemoMatch(id: 1, homeId: 1, awayId: 2, homeGoals: 3, awayGoals: 1, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 5)), goals: [GoalItem(playerId: 11, playerName: 'K. Demo', teamName: 'Antonio', goals: 2), GoalItem(playerId: 10, playerName: 'J. Test', teamName: 'Antonio', goals: 1), GoalItem(playerId: 9, playerName: 'I. Hueco', teamName: 'Iván', goals: 1)]),
    _DemoMatch(id: 2, homeId: 3, awayId: 4, homeGoals: 2, awayGoals: 2, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 4))),
    _DemoMatch(id: 3, homeId: 2, awayId: 3, homeGoals: 0, awayGoals: 1, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 3))),
    _DemoMatch(id: 4, homeId: 4, awayId: 1, homeGoals: 1, awayGoals: 4, leagueId: 1, date: DateTime.now().subtract(const Duration(days: 2)), goals: [GoalItem(playerId: 11, playerName: 'K. Demo', teamName: 'Antonio', goals: 3), GoalItem(playerId: 8, playerName: 'H. Gris', teamName: 'Antonio', goals: 1)]),
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
      goals: m.goals,
    );
  }

  static List<RankingEntry> ranking({int? leagueId}) {
    final out = <RankingEntry>[];
    for (final t in teams) {
      int played = 0, wins = 0, draws = 0, losses = 0, gf = 0, ga = 0;
      for (final m in matches) {
        if (leagueId != null && m.leagueId != leagueId) continue;
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
