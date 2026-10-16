import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'player_widgets.dart';
import 'theme.dart';

/// "Who scored?" block of the new-match screen (required: every goal is a scorer or an
/// own goal). It edits [scorers] and [ownGoals] (team id -> goals of that team that were
/// scored by the opponent, so nobody gets them) in place and calls [onChanged] after every change.
class ScorersCard extends StatelessWidget {
  final Team home;
  final Team away;
  final int homeGoals;
  final int awayGoals;
  final int? leagueId;
  final List<ScorerInput> scorers;
  final Map<int, int> ownGoals;
  final VoidCallback onChanged;

  const ScorersCard({
    super.key,
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueId,
    required this.scorers,
    required this.ownGoals,
    required this.onChanged,
  });

  int _scored(int teamId) =>
      scorers.where((s) => s.teamId == teamId).fold<int>(0, (a, s) => a + s.goals) +
      (ownGoals[teamId] ?? 0);

  Future<void> _add(BuildContext context, Team team) async {
    final player = await _choosePlayer(context, team);
    if (player == null) return;
    final existing = scorers.where((s) => s.player.id == player.id && s.teamId == team.id);
    if (existing.isNotEmpty) {
      existing.first.goals++;
    } else {
      scorers.add(ScorerInput(player: player, teamId: team.id));
    }
    onChanged();
  }

  /// Only players from the squads this team has in this league: the active
  /// squad first, then the players of its other squads.
  Future<Player?> _choosePlayer(BuildContext context, Team team) async {
    final players = <Player>[];
    var failed = false;
    if (leagueId != null) {
      try {
        final squads = await Api.squads(leagueId: leagueId, teamId: team.id);
        squads.sort((a, b) => (b.active ? 1 : 0).compareTo(a.active ? 1 : 0));
        final seen = <int>{};
        for (final squad in squads) {
          final slots = squad.slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          for (final e in slots) {
            if (seen.add(e.value.id)) players.add(e.value);
          }
        }
      } catch (_) {
        failed = true;
      }
    }
    if (!context.mounted) return null;
    if (players.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(failed
              ? 'Could not load the squad of ${team.name}.'
              : '${team.name} has no squad in this league yet. '
                  'Build one in the Squads tab to pick scorers.'),
        ));
      return null;
    }
    return showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('${team.name}: who scored?', style: displayStyle(size: 26)),
              ),
              for (final p in players)
                PlayerTile(player: p, note: p.positions, onTap: () => Navigator.pop(ctx, p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _side(BuildContext context, Team team, int goals) {
    if (goals == 0) return const SizedBox.shrink();
    final mine = scorers.where((s) => s.teamId == team.id).toList();
    final scored = _scored(team.id);
    final own = ownGoals[team.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
              const Spacer(),
              Text('$scored / $goals',
                  style: TextStyle(
                      color: scored == goals ? AppColors.text : const Color(0xFFFFC83D),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          for (final s in mine)
            Row(
              children: [
                Expanded(
                  child: Text(s.player.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () {
                    s.goals--;
                    if (s.goals <= 0) scorers.remove(s);
                    onChanged();
                  },
                ),
                SizedBox(
                  width: 22,
                  child: Text('${s.goals}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: scored >= goals
                      ? null
                      : () {
                          s.goals++;
                          onChanged();
                        },
                ),
              ],
            ),
          if (own > 0)
            Row(
              children: [
                const Expanded(
                  child: Text('Own goal (by the opponent)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDim)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () {
                    if (own <= 1) {
                      ownGoals.remove(team.id);
                    } else {
                      ownGoals[team.id] = own - 1;
                    }
                    onChanged();
                  },
                ),
                SizedBox(
                  width: 22,
                  child: Text('$own',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: scored >= goals
                      ? null
                      : () {
                          ownGoals[team.id] = own + 1;
                          onChanged();
                        },
                ),
              ],
            ),
          if (scored < goals)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _add(context, team),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add scorer'),
                ),
                if (own == 0)
                  TextButton.icon(
                    onPressed: () {
                      ownGoals[team.id] = 1;
                      onChanged();
                    },
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Own goal'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who scored?', style: displayStyle(size: 24)),
          const SizedBox(height: 2),
          const Text(
            'Required: assign every goal. Only players from the squads of each team in this league. '
            'If it was an own goal, use "Own goal": it counts for the team but nobody gets it.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          _side(context, home, homeGoals),
          _side(context, away, awayGoals),
        ],
      ),
    );
  }
}
