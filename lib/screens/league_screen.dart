import 'package:flutter/material.dart';

import '../api.dart';
import '../async_view.dart';
import '../best_xi.dart';
import '../league_dialogs.dart';
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

  Future<void> _editLeague(League league) async {
    final nameController = TextEditingController(text: league.name);
    final budgetController = TextEditingController(text: '${league.budgetMillions ?? ''}');
    final result = await showDialog<({String name, int? budget})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Edit league', style: displayStyle(size: 28)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'League name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Squad budget (empty = no limit)',
                    suffixText: 'M€',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [200, 300, 400, 500])
                      ActionChip(
                        label: Text('${m}M'),
                        backgroundColor: AppColors.surfaceHi,
                        side: BorderSide.none,
                        onPressed: () => setLocal(() => budgetController.text = '$m'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Squads already saved are not changed, but they cannot be saved again '
                  'above a lower budget.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (
                name: nameController.text.trim(),
                budget: int.tryParse(budgetController.text.trim()),
              )),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.name.isEmpty) return;
    try {
      await Api.updateLeague(league, name: result.name, budgetMillions: result.budget);
      notifyDataChanged();
      if (!mounted) return;
      _toast(context, 'League updated');
    } catch (e) {
      if (!mounted) return;
      _toast(context, e.toString());
    }
  }

  /// Two steps: see what will be lost, then type the league name to confirm.
  Future<void> _deleteLeague(League league) async {
    ({int matches, int squads, int ratings}) impact;
    try {
      impact = await Api.leagueImpact(league.id);
    } catch (e) {
      if (!mounted) return;
      _toast(context, e.toString());
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteLeagueDialog(league: league, impact: impact),
    );
    if (confirmed != true) return;
    try {
      await Api.deleteLeague(league.id);
      notifyDataChanged();
      if (!mounted) return;
      _toast(context, 'League "${league.name}" deleted');
    } catch (e) {
      if (!mounted) return;
      _toast(context, e.toString());
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
      return EmptyView(
        title: 'No leagues yet',
        message: 'Create the first league and its page will show up here.',
        actionLabel: 'Create a league',
        onAction: () => showCreateLeagueDialog(context),
      );
    }

    final leagueId = _leagueId!;
    final league = _leagues.firstWhere((l) => l.id == leagueId);

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LeagueChips(
                  leagues: _leagues,
                  selectedId: _leagueId,
                  onSelected: (id) => setState(() => _leagueId = id),
                  onNew: () => showCreateLeagueDialog(context),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'League options',
                icon: const Icon(Icons.more_vert, color: AppColors.textDim),
                onSelected: (v) {
                  if (v == 'delete') _deleteLeague(league);
                  if (v == 'budget') _editLeague(league);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'budget',
                    child: Text(league.budgetMillions == null
                        ? 'Edit name / budget…'
                        : 'Edit name / budget (${league.budgetMillions}M)…'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete this league…'),
                  ),
                ],
              ),
            ],
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

  Future<void> _reveal(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reveal all squads?', style: displayStyle(size: 28)),
        content: Text(
          'Everyone will be able to see the squads of every team in "${league.name}". '
          'It cannot be hidden again. Do it when everybody has chosen their players.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reveal squads')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.revealLeague(league.id);
      notifyDataChanged();
    } catch (e) {
      if (context.mounted) _toast(context, e.toString());
    }
  }

  Future<void> _open(BuildContext context, Squad squad) async {
    if (squad.locked) {
      _toast(context, 'Hidden until the squads are revealed. Unlock your own team in the Squads tab.');
      return;
    }
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
            if (!league.squadsRevealed)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock, size: 18, color: AppColors.textDim),
                        SizedBox(width: 8),
                        Text('Squads are hidden',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Each team only sees its own squad (with its PIN). Reveal them all when '
                      'everybody has chosen their players.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _reveal(context),
                      child: const Text('Reveal squads'),
                    ),
                  ],
                ),
              ),
            for (final team in data.teams) ...[
              _TeamSquadCard(
                team: team,
                squad: _activeOf(data.squads, team.id),
                total: data.squads.where((s) => s.teamId == team.id).length,
                onOpen: (squad) => _open(context, squad),
                onCreate: () async {
                  await _open(
                    context,
                    Squad(
                      leagueId: league.id,
                      teamId: team.id,
                      teamName: team.name,
                      leagueName: league.name,
                      name: 'Main squad',
                      formation: '4-3-3',
                    ),
                  );
                },
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
                                  : s.locked
                                      ? 'Hidden until the squads are revealed'
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
              emptyMessage: 'The best XI is built from the marks given to the players after '
                  'each match ("How did they play?" when you save a result). '
                  'Save a match with marks and it appears here.',
            ),
            if (rows.isNotEmpty) ...[
              const SectionTitle('Average marks',
                  hint: 'Best average first. In brackets: matches marked'),
              for (final r in rows)
                PlayerTile(
                  player: r.player,
                  note: r.teams.join(', '),
                  onTap: () => showPlayerDetail(context, r.player),
                  trailingOverride: Container(
                    width: 64,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: markColor(r.rating!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${r.rating!.toStringAsFixed(2)} (${r.ratedIn})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.ink),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DeleteLeagueDialog extends StatefulWidget {
  final League league;
  final ({int matches, int squads, int ratings}) impact;

  const _DeleteLeagueDialog({required this.league, required this.impact});

  @override
  State<_DeleteLeagueDialog> createState() => _DeleteLeagueDialogState();
}

class _DeleteLeagueDialogState extends State<_DeleteLeagueDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final i = widget.impact;
    final empty = i.matches == 0 && i.squads == 0 && i.ratings == 0;
    final matches = _controller.text.trim() == widget.league.name;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Delete "${widget.league.name}"?', style: displayStyle(size: 28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            empty
                ? 'This league is empty, nothing else will be lost.'
                : 'This will permanently delete the league together with '
                    '${_plural(i.matches, 'match')} (and their scorers), '
                    '${_plural(i.squads, 'squad')} and ${_plural(i.ratings, 'player rating')}. '
                    'The MegaLeague table is recalculated without those matches.',
            style: const TextStyle(height: 1.4),
          ),
          if (!empty) ...[
            const SizedBox(height: 10),
            const Text(
              'There is no undo. Tip: download a backup first (download icon, top right).',
              style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Text('Type the league name to confirm:',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.league.name),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep league'),
        ),
        TextButton(
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete league'),
        ),
      ],
    );
  }
}
