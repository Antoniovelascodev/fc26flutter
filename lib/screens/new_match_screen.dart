import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../ratings_card.dart';
import '../scorers_card.dart';
import '../theme.dart';
import '../widgets.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  List<Team> _teams = [];
  List<League> _leagues = [];
  bool _loading = true;
  Object? _error;
  bool _saving = false;

  int? _leagueId;
  int? _homeId;
  int? _awayId;
  int _homeGoals = 0;
  int _awayGoals = 0;
  final List<ScorerInput> _scorers = [];
  final List<MatchMark> _marks = [];
  int _marksReset = 0;

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

  Team? _byId(int? id) {
    for (final t in _teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.teams(), Api.leagues()]);
      if (!mounted) return;
      setState(() {
        _teams = results[0] as List<Team>;
        _leagues = results[1] as List<League>;
        _error = null;
        _loading = false;
        if (_byId(_homeId) == null) _homeId = null;
        if (_byId(_awayId) == null) _awayId = null;
        if (!_leagues.any((l) => l.id == _leagueId)) {
          _leagueId = _leagues.isNotEmpty ? _leagues.last.id : null;
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

  /// Keeps the scorers consistent with the teams and goals on screen.
  void _syncScorers() {
    _scorers.removeWhere((s) => s.teamId != _homeId && s.teamId != _awayId);
    for (final teamId in [_homeId, _awayId]) {
      final goals = teamId == _homeId ? _homeGoals : _awayGoals;
      var total = _scorers.where((s) => s.teamId == teamId).fold<int>(0, (a, s) => a + s.goals);
      for (final s in _scorers.where((s) => s.teamId == teamId).toList().reversed) {
        while (total > goals && s.goals > 0) {
          s.goals--;
          total--;
        }
        if (s.goals <= 0) _scorers.remove(s);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createDefaultTeams() async {
    try {
      for (final name in ['Antonio', 'Iván', 'Marcos', 'Mix']) {
        await Api.createTeam(name);
      }
      notifyDataChanged();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _createLeague() async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final result = await showDialog<({String name, int? budget})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('New league', style: displayStyle(size: 28)),
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
                const Text('Squad budget (maximum value of a squad)',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Millions of euros (empty = no limit)',
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
              child: const Text('Create league'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.name.isEmpty) return;
    try {
      await Api.createLeague(result.name, budgetMillions: result.budget);
      notifyDataChanged();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _pick({required bool home}) async {
    final team = await pickTeam(
      context,
      _teams,
      disabledId: home ? _awayId : _homeId,
      selectedId: home ? _homeId : _awayId,
    );
    if (team == null) return;
    setState(() {
      if (home) {
        _homeId = team.id;
      } else {
        _awayId = team.id;
      }
      _syncScorers();
    });
  }

  Future<void> _submit() async {
    final home = _byId(_homeId);
    final away = _byId(_awayId);
    if (_leagueId == null) return _toast('Create a league first');
    if (home == null || away == null) return _toast('Choose both teams');
    final hg = _homeGoals;
    final ag = _awayGoals;

    setState(() => _saving = true);
    try {
      await Api.createMatch(
        homeTeamId: home.id,
        awayTeamId: away.id,
        homeGoals: hg,
        awayGoals: ag,
        leagueId: _leagueId!,
        scorers: List.of(_scorers),
        marks: List.of(_marks),
      );
      if (!mounted) return;
      setState(() {
        _homeGoals = 0;
        _awayGoals = 0;
        _scorers.clear();
        _marks.clear();
        _marksReset++; // makes the marks card load a fresh 6 for everybody
      });
      _toast('Saved: ${home.name} $hg-$ag ${away.name}');
      notifyDataChanged();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
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
          _load();
        },
      );
    }

    if (_teams.length < 2) {
      return EmptyView(
        title: 'Add the players',
        message: 'You need at least two teams to save a match.',
        actionLabel: 'Add Antonio, Iván, Marcos and Mix',
        onAction: _createDefaultTeams,
      );
    }

    final home = _byId(_homeId);
    final away = _byId(_awayId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        if (_leagues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _createLeague,
              icon: const Icon(Icons.add),
              label: const Text('Create your first league'),
            ),
          )
        else
          LeagueChips(
            leagues: _leagues,
            selectedId: _leagueId,
            onSelected: (id) => setState(() => _leagueId = id),
            onNew: _createLeague,
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SidePanel(
                  label: 'Home',
                  team: home,
                  goals: _homeGoals,
                  onPickTeam: () => _pick(home: true),
                  onGoal: () => setState(() { if (_homeGoals < 99) _homeGoals++; }),
                  onUndo: () => setState(() {
                    _homeGoals--;
                    _syncScorers();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SidePanel(
                  label: 'Away',
                  team: away,
                  goals: _awayGoals,
                  onPickTeam: () => _pick(home: false),
                  onGoal: () => setState(() { if (_awayGoals < 99) _awayGoals++; }),
                  onUndo: () => setState(() {
                    _awayGoals--;
                    _syncScorers();
                  }),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Text(
            'Tap a score to add a goal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 13),
          ),
        ),
        if (home != null && away != null && _homeGoals + _awayGoals > 0)
          ScorersCard(
            home: home,
            away: away,
            homeGoals: _homeGoals,
            awayGoals: _awayGoals,
            leagueId: _leagueId,
            scorers: _scorers,
            onChanged: () => setState(() {}),
          ),
        if (home != null && away != null)
          RatingsCard(
            key: ValueKey('marks-${home.id}-${away.id}-$_leagueId-$_marksReset'),
            home: home,
            away: away,
            leagueId: _leagueId,
            marks: _marks,
            onChanged: () => setState(() {}),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                  )
                : const Text('Save result'),
          ),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  final String label;
  final Team? team;
  final int goals;
  final VoidCallback onPickTeam;
  final VoidCallback onGoal;
  final VoidCallback onUndo;

  const _SidePanel({
    required this.label,
    required this.team,
    required this.goals,
    required this.onPickTeam,
    required this.onGoal,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final color = team == null ? AppColors.line : teamColor(team!.name);
    final bg = team == null ? AppColors.surface : teamWash(color, strength: 52);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: team == null ? AppColors.line : color.withAlpha(170),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onPickTeam,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          team?.name ?? 'Choose team',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: displayStyle(
                            size: 28,
                            color: team == null ? AppColors.textDim : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppColors.textDim),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onGoal,
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    '$goals',
                    key: ValueKey(goals),
                    style: displayStyle(
                      size: 132,
                      weight: FontWeight.w900,
                      color: team == null ? AppColors.textDim : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextButton.icon(
              onPressed: goals > 0 ? onUndo : null,
              icon: const Icon(Icons.remove, size: 18),
              label: const Text('Undo goal'),
            ),
          ),
        ],
      ),
    );
  }
}
