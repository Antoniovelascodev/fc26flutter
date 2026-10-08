import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'squad_builder_screen.dart';

/// Pick a league and a team, then see / create / edit that team's squads.
class SquadsScreen extends StatefulWidget {
  const SquadsScreen({super.key});

  @override
  State<SquadsScreen> createState() => _SquadsScreenState();
}

class _SquadsScreenState extends State<SquadsScreen> {
  List<League> _leagues = [];
  List<Team> _teams = [];
  bool _loading = true;
  Object? _error;

  int? _leagueId;
  int? _teamId;
  Future<List<Squad>>? _squads;

  @override
  void initState() {
    super.initState();
    _load();
    dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.leagues(), Api.teams()]);
      if (!mounted) return;
      setState(() {
        _leagues = results[0] as List<League>;
        _teams = results[1] as List<Team>;
        _error = null;
        _loading = false;
        if (!_leagues.any((l) => l.id == _leagueId)) {
          _leagueId = _leagues.isNotEmpty ? _leagues.last.id : null;
        }
        if (!_teams.any((t) => t.id == _teamId)) {
          _teamId = _teams.isNotEmpty ? _teams.first.id : null;
        }
        _reloadSquads();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _reloadSquads() {
    _squads = (_leagueId == null || _teamId == null)
        ? null
        : Api.squads(leagueId: _leagueId, teamId: _teamId);
  }

  Team? get _team {
    for (final t in _teams) {
      if (t.id == _teamId) return t;
    }
    return null;
  }

  League? get _league {
    for (final l in _leagues) {
      if (l.id == _leagueId) return l;
    }
    return null;
  }

  Future<void> _open(Squad squad) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SquadBuilderScreen(squad: squad)),
    );
    if (changed == true && mounted) {
      setState(_reloadSquads);
    }
  }

  void _createSquad(int existing) {
    final team = _team;
    final league = _league;
    if (team == null || league == null) return;
    _open(Squad(
      leagueId: league.id,
      teamId: team.id,
      teamName: team.name,
      leagueName: league.name,
      name: existing == 0 ? 'Main squad' : 'Squad ${existing + 1}',
      formation: '4-3-3',
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    if (_leagues.isEmpty || _teams.isEmpty) {
      return const EmptyView(
        title: 'No leagues yet',
        message: 'Create a league (and the teams) in New match first. '
            'Then you can build a squad for each team in each league.',
      );
    }

    return Column(
      children: [
        LeagueChips(
          leagues: _leagues,
          selectedId: _leagueId,
          onSelected: (id) => setState(() {
            _leagueId = id;
            _reloadSquads();
          }),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in _teams)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: CircleAvatar(radius: 6, backgroundColor: teamColor(t.name)),
                    label: Text(t.name),
                    selected: t.id == _teamId,
                    showCheckmark: false,
                    selectedColor: teamWash(teamColor(t.name), strength: 90),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                        color: t.id == _teamId ? teamColor(t.name) : AppColors.line),
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.text),
                    onSelected: (_) => setState(() {
                      _teamId = t.id;
                      _reloadSquads();
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FutureBuilder<List<Squad>>(
            future: _squads,
            builder: (context, snap) {
              if (_squads == null) return const SizedBox.shrink();
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  error: snap.error!,
                  onRetry: () => setState(_reloadSquads),
                );
              }
              final squads = snap.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (squads.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'This team has no squad in this league yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textDim),
                      ),
                    ),
                  for (final s in squads) _SquadCard(squad: s, onTap: () => _open(s)),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: () => _createSquad(squads.length),
                    icon: const Icon(Icons.add),
                    label: const Text('New squad'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Player data: "FC 26 (FIFA 26) Player Data" by rovnez on Kaggle (CC BY 4.0), '
                      'collected from sofifa.com. Private use among friends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim, fontSize: 10, height: 1.4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SquadCard extends StatelessWidget {
  final Squad squad;
  final VoidCallback onTap;

  const _SquadCard({required this.squad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = teamColor(squad.teamName);
    final starters = squad.starters.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(squad.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: displayStyle(size: 26)),
                                  ),
                                  if (squad.active) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(60),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('ACTIVE',
                                          style: TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${squad.formation}  ·  $starters/11 starters  ·  '
                                '${formatValue(squad.totalValue)}',
                                style: const TextStyle(
                                    color: AppColors.textDim, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              starters == 0 ? '-' : squad.averageOverall.toStringAsFixed(1),
                              style: displayStyle(size: 32, weight: FontWeight.w900),
                            ),
                            const Text('OVR',
                                style: TextStyle(color: AppColors.textDim, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
