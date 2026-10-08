import 'package:flutter/material.dart';

import '../api.dart';
import '../async_view.dart';
import '../best_xi.dart';
import '../models.dart';
import '../player_widgets.dart';
import '../stats_widgets.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ranking_screen.dart' show LeagueTable;
import 'squad_builder_screen.dart';

/// A league's own page: matches, table, teams (active squads), stats and best XI.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  List<League> _leagues = [];
  bool _loading = true;
  Object? _error;
  int? _leagueId;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
    dataVersion.addListener(_loadLeagues);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_loadLeagues);
    super.dispose();
  }

  Future<void> _loadLeagues() async {
    try {
      final leagues = await Api.leagues();
      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _error = null;
        _loading = false;
        if (!leagues.any((l) => l.id == _leagueId)) {
          _leagueId = leagues.isNotEmpty ? leagues.last.id : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() => _loading = true);
          _loadLeagues();
        },
      );
    }
    if (_leagues.isEmpty) {
      return const EmptyView(
        title: 'No leagues yet',
        message: 'Create a league in New match and its page will show up here.',
      );
    }

    final leagueId = _leagueId!;
    final league = _leagues.firstWhere((l) => l.id == leagueId);

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          LeagueChips(
            leagues: _leagues,
            selectedId: _leagueId,
            onSelected: (id) => setState(() => _leagueId = id),
          ),
          const SizedBox(height: 4),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: AppColors.line,
            indicatorColor: AppColors.text,
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.textDim,
            tabs: [
              Tab(text: 'Matches'),
              Tab(text: 'Table'),
              Tab(text: 'Teams'),
              Tab(text: 'Stats'),
              Tab(text: 'Best XI'),
            ],
          ),
          Expanded(
            child: TabBarView(
              // A new key per league so every tab reloads when another league is chosen.
              key: ValueKey('league-$leagueId'),
              children: [
                _MatchesTab(leagueId: leagueId),
                _TableTab(leagueId: leagueId),
                _TeamsTab(league: league),
                _StatsTab(leagueId: leagueId),
                _BestXiTab(leagueId: leagueId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Matches
// ---------------------------------------------------------------------------

class _MatchesTab extends StatelessWidget {
  final int leagueId;

  const _MatchesTab({required this.leagueId});

  Future<void> _confirmDelete(BuildContext context, MatchItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this match?', style: displayStyle(size: 28)),
        content: Text(
          '${m.homeTeamName} ${m.homeGoals}-${m.awayGoals} ${m.awayTeamName}\n'
          'The tables and scorers will be recalculated without it.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep match')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete match')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteMatch(m.id);
      notifyDataChanged();
      if (!context.mounted) return;
      _toast(context, 'Match deleted');
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<MatchItem>>(
      key: ValueKey('matches-$leagueId'),
      load: () => Api.matchesByLeague(leagueId),
      builder: (context, matches) {
        if (matches.isEmpty) {
          return const EmptyView(
            title: 'Nothing played here yet',
            message: 'Matches saved in this league will be listed here, newest first.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: matches.length,
          itemBuilder: (context, i) => MatchStrip(
            match: matches[i],
            onDelete: () => _confirmDelete(context, matches[i]),
          ),
        );
      },
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

class _TableTab extends StatelessWidget {
  final int leagueId;

  const _TableTab({required this.leagueId});

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<RankingEntry>>(
      key: ValueKey('table-$leagueId'),
      load: () => Api.standings(leagueId),
      builder: (context, entries) {
        if (entries.isEmpty) {
          return const EmptyView(
            title: 'No results yet',
            message: 'The table of this league starts with its first match.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 24),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: LeagueTable(entries: entries),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Teams: the active squad of each team in this league
// ---------------------------------------------------------------------------

class _TeamsData {
  final List<Team> teams;
  final List<Squad> squads;

  _TeamsData(this.teams, this.squads);
}

class _TeamsTab extends StatelessWidget {
  final League league;

  const _TeamsTab({required this.league});

  Future<_TeamsData> _load() async {
    final results = await Future.wait([Api.teams(), Api.squads(leagueId: league.id)]);
    return _TeamsData(results[0] as List<Team>, results[1] as List<Squad>);
  }

  Future<void> _open(BuildContext context, Squad squad) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SquadBuilderScreen(squad: squad)),
    );
    if (changed == true) notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_TeamsData>(
      key: ValueKey('teams-${league.id}'),
      load: _load,
      builder: (context, data) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            for (final team in data.teams) ...[
              _TeamSquadCard(
                team: team,
                squad: _activeOf(data.squads, team.id),
                total: data.squads.where((s) => s.teamId == team.id).length,
                onOpen: (squad) => _open(context, squad),
                onCreate: () => _open(
                  context,
                  Squad(
                    leagueId: league.id,
                    teamId: team.id,
                    teamName: team.name,
                    leagueName: league.name,
                    name: 'Main squad',
                    formation: '4-3-3',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Squad? _activeOf(List<Squad> squads, int teamId) {
    final mine = squads.where((s) => s.teamId == teamId).toList();
    if (mine.isEmpty) return null;
    return mine.firstWhere((s) => s.active, orElse: () => mine.first);
  }
}

class _TeamSquadCard extends StatelessWidget {
  final Team team;
  final Squad? squad;
  final int total;
  final ValueChanged<Squad> onOpen;
  final VoidCallback onCreate;

  const _TeamSquadCard({
    required this.team,
    required this.squad,
    required this.total,
    required this.onOpen,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final color = teamColor(team.name);
    final s = squad;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: s == null ? onCreate : () => onOpen(s),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.name, style: displayStyle(size: 28)),
                            const SizedBox(height: 4),
                            Text(
                              s == null
                                  ? 'No squad yet. Tap to build one.'
                                  : '${s.name}  ·  ${s.formation}  ·  ${s.starters.length}/11 starters'
                                      '${total > 1 ? '  ·  $total squads' : ''}',
                              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (s != null && s.starters.isNotEmpty)
                        Column(
                          children: [
                            Text(s.averageOverall.toStringAsFixed(1),
                                style: displayStyle(size: 32, weight: FontWeight.w900)),
                            const Text('OVR',
                                style: TextStyle(color: AppColors.textDim, fontSize: 10)),
                          ],
                        )
                      else
                        const Icon(Icons.chevron_right, color: AppColors.textDim),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats: scorers and most used players
// ---------------------------------------------------------------------------

class _StatsTab extends StatelessWidget {
  final int leagueId;

  const _StatsTab({required this.leagueId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        const SectionTitle('Top scorers'),
        AsyncView<List<ScorerRow>>(
          key: ValueKey('scorers-$leagueId'),
          compact: true,
          load: () => Api.topScorers(leagueId: leagueId),
          builder: (context, rows) => ScorerList(rows: rows, limit: 15),
        ),
        const SectionTitle('Most used players',
            hint: 'Players in the active squads of this league'),
        AsyncView<List<MostUsedRow>>(
          key: ValueKey('used-$leagueId'),
          compact: true,
          load: () => Api.mostUsed(leagueId: leagueId),
          builder: (context, rows) => MostUsedList(rows: rows, limit: 15),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Best XI: one agreed rating per player, best XI of the league
// ---------------------------------------------------------------------------

class _BestXiTab extends StatelessWidget {
  final int leagueId;

  const _BestXiTab({required this.leagueId});

  Future<void> _rate(BuildContext context, RatingRow row) async {
    final result = await showModalBottomSheet<_RatingChoice>(
      context: context,
      builder: (ctx) => _RatingSheet(row: row),
    );
    if (result == null) return;
    try {
      await Api.rate(leagueId, row.player.id, result.remove ? null : result.value);
      notifyDataChanged();
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<RatingRow>>(
      key: ValueKey('xi-$leagueId'),
      load: () => Api.leagueRatings(leagueId),
      builder: (context, rows) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            BestXiView(
              rows: rows,
              emptyMessage: rows.isEmpty
                  ? 'First build a squad for each team in this league (Squads tab). '
                      'The players you use appear here so you can rate them.'
                  : 'Rate some players below and the best XI of this league appears here.',
            ),
            const SectionTitle('Rate the players',
                hint: 'One rating from 0 to 10, agreed by the group'),
            if (rows.isEmpty)
              const Text('No players in the squads of this league yet.',
                  style: TextStyle(color: AppColors.textDim)),
            for (final r in rows)
              PlayerTile(
                player: r.player,
                note: r.teams.join(', '),
                onTap: () => _rate(context, r),
                trailingOverride: Container(
                  width: 52,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: r.rating == null ? AppColors.surfaceHi : const Color(0xFFFFD166),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r.rating == null ? 'Rate' : formatRating(r.rating!),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.rating == null ? AppColors.textDim : AppColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RatingChoice {
  final double value;
  final bool remove;

  _RatingChoice(this.value, {this.remove = false});
}

class _RatingSheet extends StatefulWidget {
  final RatingRow row;

  const _RatingSheet({required this.row});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late double _value = widget.row.rating ?? 7;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerTile(player: widget.row.player),
            const SizedBox(height: 8),
            Text(formatRating(_value), style: displayStyle(size: 64, weight: FontWeight.w900)),
            Slider(
              value: _value,
              min: 0,
              max: 10,
              divisions: 20,
              label: formatRating(_value),
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _RatingChoice(_value)),
              child: const Text('Save rating'),
            ),
            if (widget.row.rating != null)
              TextButton(
                onPressed: () => Navigator.pop(context, _RatingChoice(0, remove: true)),
                child: const Text('Remove rating'),
              ),
          ],
        ),
      ),
    );
  }
}
