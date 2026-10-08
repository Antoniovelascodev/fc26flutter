import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'player_widgets.dart';
import 'theme.dart';

/// Optional "who scored?" block of the new-match screen. It edits [scorers] in
/// place and calls [onChanged] after every change.
class ScorersCard extends StatelessWidget {
  final Team home;
  final Team away;
  final int homeGoals;
  final int awayGoals;
  final int? leagueId;
  final List<ScorerInput> scorers;
  final VoidCallback onChanged;

  const ScorersCard({
    super.key,
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.leagueId,
    required this.scorers,
    required this.onChanged,
  });

  int _scored(int teamId) => scorers
      .where((s) => s.teamId == teamId)
      .fold<int>(0, (a, s) => a + s.goals);

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

  /// The active squad of the team first; "Search any player" as a way out.
  Future<Player?> _choosePlayer(BuildContext context, Team team) async {
    List<Player> squadPlayers = [];
    if (leagueId != null) {
      try {
        final squads = await Api.squads(leagueId: leagueId, teamId: team.id);
        final active = squads.where((s) => s.active).toList();
        if (active.isNotEmpty) {
          final slots = active.first.slots.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          squadPlayers = slots.map((e) => e.value).toList();
        }
      } catch (_) {
        // No squad available: fall back to the search.
      }
    }
    if (!context.mounted) return null;
    if (squadPlayers.isEmpty) {
      return pickPlayer(context);
    }
    final choice = await showModalBottomSheet<Object>(
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
              for (final p in squadPlayers)
                PlayerTile(player: p, note: p.positions, onTap: () => Navigator.pop(ctx, p)),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search any player…'),
                onTap: () => Navigator.pop(ctx, 'search'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice is Player) return choice;
    if (choice == 'search' && context.mounted) return pickPlayer(context);
    return null;
  }

  Widget _side(BuildContext context, Team team, int goals) {
    if (goals == 0) return const SizedBox.shrink();
    final mine = scorers.where((s) => s.teamId == team.id).toList();
    final scored = _scored(team.id);
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
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
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
          if (scored < goals)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _add(context, team),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add scorer'),
              ),
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
          Text('Who scored? (optional)', style: displayStyle(size: 24)),
          const SizedBox(height: 2),
          const Text(
            'You can leave it empty, or add only the goals you know.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          _side(context, home, homeGoals),
          _side(context, away, awayGoals),
        ],
      ),
    );
  }
}
