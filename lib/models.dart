int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

class Team {
  final int id;
  final String name;

  /// true when the team has a PIN protecting its squads.
  final bool hasPin;

  Team({required this.id, required this.name, this.hasPin = false});

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: _toInt(j['id']),
        name: j['name'] as String? ?? '',
        hasPin: j['hasPin'] == true,
      );
}

class League {
  final int id;
  final String name;
  final String? description;

  /// false = the squads of each team are hidden from the others for now.
  final bool squadsRevealed;

  League({
    required this.id,
    required this.name,
    this.description,
    this.squadsRevealed = true,
  });

  factory League.fromJson(Map<String, dynamic> j) => League(
        id: _toInt(j['id']),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        squadsRevealed: j['squadsRevealed'] != false,
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
  final List<GoalItem> goals;

  MatchItem({
    required this.id,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueName,
    required this.matchDate,
    required this.result,
    this.goals = const [],
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
        goals: ((j['goals'] as List?) ?? [])
            .map((e) => GoalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<GoalItem> goalsOf(String teamName) =>
      goals.where((g) => g.teamName == teamName).toList();
}

/// A scorer of a saved match.
class GoalItem {
  final int playerId;
  final String playerName;
  final String teamName;
  final int goals;

  GoalItem({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.goals,
  });

  factory GoalItem.fromJson(Map<String, dynamic> j) => GoalItem(
        playerId: _toInt(j['playerId']),
        playerName: j['playerName'] as String? ?? '',
        teamName: j['teamName'] as String? ?? '',
        goals: _toInt(j['goals']),
      );
}

/// The mark of a player in a new match (everybody starts with a 6).
class MatchMark {
  final Player player;
  final int teamId;
  final bool bench;
  double rating;
  bool played;

  MatchMark({
    required this.player,
    required this.teamId,
    this.bench = false,
    this.rating = 6,
    this.played = true,
  });
}

/// A scorer being entered for a new match.
class ScorerInput {
  final Player player;
  final int teamId;
  int goals;

  ScorerInput({required this.player, required this.teamId, this.goals = 1});
}

class ScorerRow {
  final Player player;
  final String teamName;
  final int goals;

  ScorerRow({required this.player, required this.teamName, required this.goals});

  factory ScorerRow.fromJson(Map<String, dynamic> j) => ScorerRow(
        player: Player.fromJson(j['player'] as Map<String, dynamic>),
        teamName: j['teamName'] as String? ?? '',
        goals: _toInt(j['goals']),
      );
}

class MostUsedRow {
  final Player player;
  final int squads;
  final List<String> teams;

  MostUsedRow({required this.player, required this.squads, required this.teams});

  factory MostUsedRow.fromJson(Map<String, dynamic> j) => MostUsedRow(
        player: Player.fromJson(j['player'] as Map<String, dynamic>),
        squads: _toInt(j['squads']),
        teams: ((j['teams'] as List?) ?? []).map((e) => e as String).toList(),
      );
}

/// A player that can be rated (league) or has an average rating (MegaLeague).
class RatingRow {
  final Player player;
  final double? rating;
  final int ratedIn;
  final List<String> teams;

  RatingRow({
    required this.player,
    required this.rating,
    required this.ratedIn,
    required this.teams,
  });

  factory RatingRow.fromJson(Map<String, dynamic> j) => RatingRow(
        player: Player.fromJson(j['player'] as Map<String, dynamic>),
        rating: (j['rating'] as num?)?.toDouble(),
        ratedIn: _toInt(j['ratedIn']),
        teams: ((j['teams'] as List?) ?? []).map((e) => e as String).toList(),
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

int? _toIntN(dynamic v) => (v as num?)?.toInt();

/// An attribute of a player: JSON key (= server filter name), label and group.
class StatDef {
  final String key;
  final String label;
  final String group;

  const StatDef(this.key, this.label, this.group);
}

const List<StatDef> kStats = [
  StatDef('pace', 'Pace', 'Main'),
  StatDef('shooting', 'Shooting', 'Main'),
  StatDef('passing', 'Passing', 'Main'),
  StatDef('dribbling', 'Dribbling (main)', 'Main'),
  StatDef('defending', 'Defending (main)', 'Main'),
  StatDef('physic', 'Physical', 'Main'),
  StatDef('attackingCrossing', 'Crossing', 'Attacking'),
  StatDef('attackingFinishing', 'Finishing', 'Attacking'),
  StatDef('attackingHeadingAccuracy', 'Heading accuracy', 'Attacking'),
  StatDef('attackingShortPassing', 'Short passing', 'Attacking'),
  StatDef('attackingVolleys', 'Volleys', 'Attacking'),
  StatDef('skillDribbling', 'Dribbling', 'Skill'),
  StatDef('skillCurve', 'Curve', 'Skill'),
  StatDef('skillFkAccuracy', 'Free kick accuracy', 'Skill'),
  StatDef('skillLongPassing', 'Long passing', 'Skill'),
  StatDef('skillBallControl', 'Ball control', 'Skill'),
  StatDef('movementAcceleration', 'Acceleration', 'Movement'),
  StatDef('movementSprintSpeed', 'Sprint speed', 'Movement'),
  StatDef('movementAgility', 'Agility', 'Movement'),
  StatDef('movementReactions', 'Reactions', 'Movement'),
  StatDef('movementBalance', 'Balance', 'Movement'),
  StatDef('powerShotPower', 'Shot power', 'Power'),
  StatDef('powerJumping', 'Jumping', 'Power'),
  StatDef('powerStamina', 'Stamina', 'Power'),
  StatDef('powerStrength', 'Strength', 'Power'),
  StatDef('powerLongShots', 'Long shots', 'Power'),
  StatDef('mentalityAggression', 'Aggression', 'Mentality'),
  StatDef('mentalityInterceptions', 'Interceptions', 'Mentality'),
  StatDef('mentalityPositioning', 'Positioning', 'Mentality'),
  StatDef('mentalityVision', 'Vision', 'Mentality'),
  StatDef('mentalityPenalties', 'Penalties', 'Mentality'),
  StatDef('mentalityComposure', 'Composure', 'Mentality'),
  StatDef('defendingMarkingAwareness', 'Marking', 'Defending'),
  StatDef('defendingStandingTackle', 'Standing tackle', 'Defending'),
  StatDef('defendingSlidingTackle', 'Sliding tackle', 'Defending'),
  StatDef('gkDiving', 'GK diving', 'Goalkeeping'),
  StatDef('gkHandling', 'GK handling', 'Goalkeeping'),
  StatDef('gkKicking', 'GK kicking', 'Goalkeeping'),
  StatDef('gkPositioning', 'GK positioning', 'Goalkeeping'),
  StatDef('gkReflexes', 'GK reflexes', 'Goalkeeping'),
  StatDef('gkSpeed', 'GK speed', 'Goalkeeping'),
];

/// A real FC 26 player from the imported database.
class Player {
  final int id;
  final String shortName;
  final String longName;
  final String positions; // "CAM, CM"
  final int overall;
  final int potential;
  final int? valueEur;
  final int? age;
  final String clubName;
  final String leagueName;
  final String nationalityName;
  final String preferredFoot;
  final int? weakFoot;
  final int? skillMoves;
  final int? heightCm;
  final int? pace;
  final int? shooting;
  final int? passing;
  final int? dribbling;
  final int? defending;
  final int? physic;
  final int? gkDiving;
  final int? gkHandling;
  final int? gkKicking;
  final int? gkPositioning;
  final int? gkReflexes;
  final int? gkSpeed;

  /// Every attribute in [kStats] that the server sent, by key.
  final Map<String, int> detail;

  Player({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.positions,
    required this.overall,
    required this.potential,
    this.valueEur,
    this.age,
    this.clubName = '',
    this.leagueName = '',
    this.nationalityName = '',
    this.preferredFoot = '',
    this.weakFoot,
    this.skillMoves,
    this.heightCm,
    this.pace,
    this.shooting,
    this.passing,
    this.dribbling,
    this.defending,
    this.physic,
    this.gkDiving,
    this.gkHandling,
    this.gkKicking,
    this.gkPositioning,
    this.gkReflexes,
    this.gkSpeed,
    this.detail = const {},
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: _toInt(j['id']),
        shortName: j['shortName'] as String? ?? '',
        longName: j['longName'] as String? ?? '',
        positions: j['positions'] as String? ?? '',
        overall: _toInt(j['overall']),
        potential: _toInt(j['potential']),
        valueEur: _toIntN(j['valueEur']),
        age: _toIntN(j['age']),
        clubName: j['clubName'] as String? ?? '',
        leagueName: j['leagueName'] as String? ?? '',
        nationalityName: j['nationalityName'] as String? ?? '',
        preferredFoot: j['preferredFoot'] as String? ?? '',
        weakFoot: _toIntN(j['weakFoot']),
        skillMoves: _toIntN(j['skillMoves']),
        heightCm: _toIntN(j['heightCm']),
        pace: _toIntN(j['pace']),
        shooting: _toIntN(j['shooting']),
        passing: _toIntN(j['passing']),
        dribbling: _toIntN(j['dribbling']),
        defending: _toIntN(j['defending']),
        physic: _toIntN(j['physic']),
        gkDiving: _toIntN(j['gkDiving']),
        gkHandling: _toIntN(j['gkHandling']),
        gkKicking: _toIntN(j['gkKicking']),
        gkPositioning: _toIntN(j['gkPositioning']),
        gkReflexes: _toIntN(j['gkReflexes']),
        gkSpeed: _toIntN(j['gkSpeed']),
        detail: {
          for (final s in kStats)
            if (j[s.key] is num) s.key: (j[s.key] as num).toInt(),
        },
      );

  /// An attribute by its [kStats] key, or null if unknown.
  int? stat(String key) => detail[key];

  List<String> get positionList => positions
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String get mainPosition => positionList.isEmpty ? '' : positionList.first;

  bool get isGoalkeeper => mainPosition == 'GK';

  bool canPlay(String position) => positionList.contains(position);

  /// The six headline stats, as (label, value). Goalkeepers get their own six.
  List<(String, int?)> get headlineStats => isGoalkeeper
      ? [
          ('DIV', gkDiving),
          ('HAN', gkHandling),
          ('KIC', gkKicking),
          ('REF', gkReflexes),
          ('SPD', gkSpeed),
          ('POS', gkPositioning),
        ]
      : [
          ('PAC', pace),
          ('SHO', shooting),
          ('PAS', passing),
          ('DRI', dribbling),
          ('DEF', defending),
          ('PHY', physic),
        ];
}

/// "€12.5M", "€800K"
String formatValue(int? eur) {
  if (eur == null || eur <= 0) return '-';
  if (eur >= 1000000) {
    final m = eur / 1000000;
    final text = m >= 100 ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
    return '€${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}M';
  }
  return '€${(eur / 1000).round()}K';
}

class PlayerPage {
  final List<Player> players;
  final bool hasNext;
  final int total;

  PlayerPage({required this.players, required this.hasNext, required this.total});

  factory PlayerPage.fromJson(Map<String, dynamic> j) => PlayerPage(
        players: ((j['content'] as List?) ?? [])
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasNext: j['hasNext'] as bool? ?? false,
        total: _toInt(j['total']),
      );
}

/// Starting XI (slots 0-10, in the order of the formation) + bench (11+).
class Squad {
  static const int benchStart = 11;
  static const int benchSize = 10;

  final int? id;
  final int leagueId;
  final int teamId;
  final String teamName;
  final String leagueName;
  String name;
  String formation;
  bool active;
  Map<int, Player> slots;

  /// true when the squad is hidden from this device (its owner's PIN is not known here).
  final bool locked;

  Squad({
    this.id,
    required this.leagueId,
    required this.teamId,
    this.teamName = '',
    this.leagueName = '',
    required this.name,
    required this.formation,
    this.active = false,
    Map<int, Player>? slots,
    this.locked = false,
  }) : slots = slots ?? {};

  factory Squad.fromJson(Map<String, dynamic> j) => Squad(
        id: _toInt(j['id']),
        leagueId: _toInt(j['leagueId']),
        teamId: _toInt(j['teamId']),
        teamName: j['teamName'] as String? ?? '',
        leagueName: j['leagueName'] as String? ?? '',
        name: j['name'] as String? ?? '',
        formation: j['formation'] as String? ?? '4-3-3',
        active: j['active'] as bool? ?? false,
        locked: j['locked'] == true,
        slots: {
          for (final s in (j['slots'] as List? ?? []))
            _toInt((s as Map)['slot']):
                Player.fromJson(s['player'] as Map<String, dynamic>),
        },
      );

  List<Player> get starters => [
        for (var i = 0; i < benchStart; i++)
          if (slots[i] != null) slots[i]!,
      ];

  List<Player> get bench => [
        for (final e in slots.entries)
          if (e.key >= benchStart) e.value,
      ];

  /// Average overall of the starters (0 if none).
  double get averageOverall {
    final s = starters;
    if (s.isEmpty) return 0;
    return s.fold<int>(0, (a, p) => a + p.overall) / s.length;
  }

  int get totalValue =>
      slots.values.fold<int>(0, (a, p) => a + (p.valueEur ?? 0));

  double get averageAge {
    final ages = slots.values.map((p) => p.age).whereType<int>().toList();
    if (ages.isEmpty) return 0;
    return ages.reduce((a, b) => a + b) / ages.length;
  }
}
