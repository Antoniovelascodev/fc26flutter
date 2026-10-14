import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// The "how did they play?" block of the new-match screen: every player of both
/// squads (starters and bench) starts with a 6 and can be moved in steps of 0.5.
/// It edits [marks] in place and calls [onChanged] after every change.
class RatingsCard extends StatefulWidget {
  final Team home;
  final Team away;
  final int? leagueId;
  final List<MatchMark> marks;
  final VoidCallback onChanged;

  const RatingsCard({
    super.key,
    required this.home,
    required this.away,
    required this.leagueId,
    required this.marks,
    required this.onChanged,
  });

  @override
  State<RatingsCard> createState() => _RatingsCardState();
}

class _RatingsCardState extends State<RatingsCard> {
  bool _loading = true;
  final Map<int, String> _problems = {}; // team id -> why there are no players

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    widget.marks.clear();
    for (final team in [widget.home, widget.away]) {
      try {
        final squads = await Api.squads(leagueId: widget.leagueId, teamId: team.id);
        if (squads.isEmpty) {
          _problems[team.id] = 'has no squad in this league yet';
          continue;
        }
        final squad = squads.firstWhere((s) => s.active, orElse: () => squads.first);
        if (squad.locked) {
          _problems[team.id] = 'squad is hidden until the squads are revealed';
          continue;
        }
        final slots = squad.slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        for (final e in slots) {
          widget.marks.add(MatchMark(
            player: e.value,
            teamId: team.id,
            bench: e.key >= Squad.benchStart,
          ));
        }
      } catch (_) {
        _problems[team.id] = 'squad could not be loaded';
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onChanged();
  }

  void _change(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  Color _color(double r) {
    if (r >= 8.5) return const Color(0xFFFFD166);
    if (r >= 7) return const Color(0xFF9BE564);
    if (r < 5) return AppColors.error;
    return AppColors.text;
  }

  Widget _row(MatchMark m) {
    final played = m.played;
    return Opacity(
      opacity: played ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(m.player.mainPosition,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
            ),
            Expanded(
              child: Text(m.player.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: m.bench ? FontWeight.w500 : FontWeight.w700)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: played && m.rating > 0
                  ? () => _change(() => m.rating = (m.rating - 0.5).clamp(0, 10))
                  : null,
            ),
            SizedBox(
              width: 34,
              child: Text(
                played ? (m.rating == m.rating.roundToDouble()
                    ? m.rating.toStringAsFixed(0)
                    : m.rating.toStringAsFixed(1)) : '-',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, color: _color(m.rating)),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: played && m.rating < 10
                  ? () => _change(() => m.rating = (m.rating + 0.5).clamp(0, 10))
                  : null,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: played ? 'Did not play' : 'Played',
              icon: Icon(played ? Icons.close : Icons.undo, size: 18, color: AppColors.textDim),
              onPressed: () => _change(() => m.played = !m.played),
            ),
          ],
        ),
      ),
    );
  }

  Widget _team(Team team) {
    final mine = widget.marks.where((m) => m.teamId == team.id).toList();
    final starters = mine.where((m) => !m.bench).toList();
    final bench = mine.where((m) => m.bench).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 18,
                decoration: BoxDecoration(
                  color: teamColor(team.name),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(team.name, style: displayStyle(size: 22)),
            ],
          ),
          if (_problems.containsKey(team.id))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${team.name}: ${_problems[team.id]}.',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
            ),
          for (final m in starters) _row(m),
          if (bench.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Text('Bench',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _change(() {
                      final allOut = bench.every((m) => !m.played);
                      for (final m in bench) {
                        m.played = allOut;
                      }
                    }),
                    child: Text(bench.every((m) => !m.played)
                        ? 'Bench played'
                        : "Bench didn't play"),
                  ),
                ],
              ),
            ),
            for (final m in bench) _row(m),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How did they play?', style: displayStyle(size: 24)),
                const SizedBox(height: 2),
                const Text(
                  'Whoever watched the match marks the players. Everybody starts with a 6: '
                  'only change those who stood out. The best XI is built from these marks. '
                  '✕ = did not play.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else ...[
            _team(widget.home),
            _team(widget.away),
          ],
        ],
      ),
    );
  }
}
