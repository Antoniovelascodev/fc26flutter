import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});

  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  List<Team> _teams = [];
  bool _loading = true;
  Object? _error;

  Team? _t1;
  Team? _t2;
  Future<HeadToHead>? _h2h;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    _loadTeams();
    _fetch();
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await Api.teams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _fetch() {
    if (!mounted) return;
    setState(() {
      final a = _t1;
      final b = _t2;
      _h2h = (a != null && b != null) ? Api.headToHead(a.id, b.id) : null;
    });
  }

  Future<void> _pick({required bool first}) async {
    final team = await pickTeam(
      context,
      _teams,
      disabledId: first ? _t2?.id : _t1?.id,
      selectedId: first ? _t1?.id : _t2?.id,
    );
    if (team == null) return;
    if (first) {
      _t1 = team;
    } else {
      _t2 = team;
    }
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() => _loading = true);
          _loadTeams();
        },
      );
    }
    if (_teams.length < 2) {
      return const EmptyView(
        title: 'Add the players first',
        message: 'Head to head needs two teams. Create them in New match.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(child: _Slot(team: _t1, onTap: () => _pick(first: true))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('vs', style: TextStyle(color: AppColors.textDim)),
              ),
              Expanded(child: _Slot(team: _t2, onTap: () => _pick(first: false))),
            ],
          ),
        ),
        Expanded(child: _result()),
      ],
    );
  }

  Widget _result() {
    if (_h2h == null) {
      return const EmptyView(
        title: 'Pick two teams',
        message: 'See who has the upper hand and every match they have played.',
      );
    }
    return FutureBuilder<HeadToHead>(
      future: _h2h,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: _fetch);
        }
        final h = snap.data!;
        if (h.matches.isEmpty) {
          return EmptyView(
            title: 'No matches yet',
            message: '${h.team1Name} and ${h.team2Name} have not played each other.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _Balance(h: h),
            const SizedBox(height: 18),
            for (final m in h.matches) MatchStrip(match: m),
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  final Team? team;
  final VoidCallback onTap;

  const _Slot({required this.team, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = team == null ? AppColors.line : teamColor(team!.name);
    return Material(
      color: team == null ? AppColors.surface : teamWash(color, strength: 52),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: team == null ? AppColors.line : color.withAlpha(170),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  team?.name ?? 'Choose team',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(
                    size: 26,
                    color: team == null ? AppColors.textDim : AppColors.text,
                  ),
                ),
              ),
              const Icon(Icons.expand_more, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wins for each side pulling a shared bar left or right.
class _Balance extends StatelessWidget {
  final HeadToHead h;

  const _Balance({required this.h});

  @override
  Widget build(BuildContext context) {
    final c1 = teamColor(h.team1Name);
    final c2 = teamColor(h.team2Name);

    Widget seg(int flex, Color c) =>
        Expanded(flex: flex, child: Container(color: c));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${h.team1Wins}',
                      style: displayStyle(size: 84, weight: FontWeight.w900, color: c1),
                    ),
                    Text(
                      h.team1Wins == 1 ? 'win' : 'wins',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${h.draws}',
                    style: displayStyle(size: 40, color: AppColors.textDim),
                  ),
                  Text(
                    h.draws == 1 ? 'draw' : 'draws',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${h.team2Wins}',
                      style: displayStyle(size: 84, weight: FontWeight.w900, color: c2),
                    ),
                    Text(
                      h.team2Wins == 1 ? 'win' : 'wins',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (h.team1Wins > 0) seg(h.team1Wins, c1),
                  if (h.draws > 0) seg(h.draws, AppColors.draw),
                  if (h.team2Wins > 0) seg(h.team2Wins, c2),
                  if (h.team1Wins + h.draws + h.team2Wins == 0)
                    seg(1, AppColors.line),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${h.team1GoalsFor} ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const TextSpan(text: 'goals', style: TextStyle(color: AppColors.textDim)),
                ]),
              ),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${h.team2GoalsFor} ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const TextSpan(text: 'goals', style: TextStyle(color: AppColors.textDim)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
