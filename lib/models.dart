int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

class Team {
  final int id;
  final String name;

  Team({required this.id, required this.name});

  factory Team.fromJson(Map<String, dynamic> j) =>
      Team(id: _toInt(j['id']), name: j['name'] as String? ?? '');
}

class League {
  final int id;
  final String name;
  final String? description;

  League({required this.id, required this.name, this.description});

  factory League.fromJson(Map<String, dynamic> j) => League(
        id: _toInt(j['id']),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
      );
}

/// One row of the MegaLeague table.
class RankingEntry {
  final String teamName;
  final int points;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;

  RankingEntry({
    required this.teamName,
    required this.points,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
        teamName: j['teamName'] as String? ?? '',
        points: _toInt(j['points']),
        matchesPlayed: _toInt(j['matchesPlayed']),
        wins: _toInt(j['wins']),
        draws: _toInt(j['draws']),
        losses: _toInt(j['losses']),
        goalsFor: _toInt(j['goalsFor']),
        goalsAgainst: _toInt(j['goalsAgainst']),
        goalDifference: _toInt(j['goalDifference']),
      );
}

class MatchItem {
  final int id;
  final String homeTeamName;
  final String awayTeamName;
  final int homeGoals;
  final int awayGoals;
  final String leagueName;
  final DateTime? matchDate;
  final String result; // HOME_WIN, AWAY_WIN, DRAW

  MatchItem({
    required this.id,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueName,
    required this.matchDate,
    required this.result,
  });

  factory MatchItem.fromJson(Map<String, dynamic> j) => MatchItem(
        id: _toInt(j['id']),
        homeTeamName: j['homeTeamName'] as String? ?? '',
        awayTeamName: j['awayTeamName'] as String? ?? '',
        homeGoals: _toInt(j['homeGoals']),
        awayGoals: _toInt(j['awayGoals']),
        leagueName: j['leagueName'] as String? ?? '',
        matchDate: DateTime.tryParse(j['matchDate'] as String? ?? ''),
        result: j['result'] as String? ?? 'DRAW',
      );
}

class HeadToHead {
  final String team1Name;
  final String team2Name;
  final int team1Wins;
  final int team2Wins;
  final int draws;
  final int team1GoalsFor;
  final int team2GoalsFor;
  final List<MatchItem> matches;

  HeadToHead({
    required this.team1Name,
    required this.team2Name,
    required this.team1Wins,
    required this.team2Wins,
    required this.draws,
    required this.team1GoalsFor,
    required this.team2GoalsFor,
    required this.matches,
  });

  factory HeadToHead.fromJson(Map<String, dynamic> j) => HeadToHead(
        team1Name: j['team1Name'] as String? ?? '',
        team2Name: j['team2Name'] as String? ?? '',
        team1Wins: _toInt(j['team1Wins']),
        team2Wins: _toInt(j['team2Wins']),
        draws: _toInt(j['draws']),
        team1GoalsFor: _toInt(j['team1GoalsFor']),
        team2GoalsFor: _toInt(j['team2GoalsFor']),
        matches: ((j['matches'] as List?) ?? [])
            .map((e) => MatchItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
