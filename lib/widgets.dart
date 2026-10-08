import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]}, ${two(d.hour)}:${two(d.minute)}';
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textDim),
            const SizedBox(height: 14),
            Text("Can't reach the server", style: displayStyle(size: 28)),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: displayStyle(size: 30), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// Win / draw / loss proportions as one thin bar.
class RecordBar extends StatelessWidget {
  final int wins;
  final int draws;
  final int losses;

  const RecordBar({
    super.key,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    Widget seg(int flex, Color c) =>
        Expanded(flex: flex, child: Container(color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: (wins + draws + losses) == 0
            ? Container(color: AppColors.line)
            : Row(children: [
                if (wins > 0) seg(wins, AppColors.text),
                if (draws > 0) seg(draws, AppColors.draw),
                if (losses > 0) seg(losses, AppColors.loss),
              ]),
      ),
    );
  }
}

/// League selector as a horizontal row of chips.
class LeagueChips extends StatelessWidget {
  final List<League> leagues;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback? onNew;

  const LeagueChips({
    super.key,
    required this.leagues,
    required this.selectedId,
    required this.onSelected,
    this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final l in leagues)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(l.name),
                selected: l.id == selectedId,
                showCheckmark: false,
                selectedColor: AppColors.text,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.line),
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: l.id == selectedId ? AppColors.ink : AppColors.text,
                ),
                onSelected: (_) => onSelected(l.id),
              ),
            ),
          if (onNew != null)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18, color: AppColors.textDim),
              label: const Text('New league'),
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: AppColors.line),
              shape: const StadiumBorder(),
              labelStyle: const TextStyle(color: AppColors.textDim),
              onPressed: onNew,
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose a team. Returns null if dismissed.
Future<Team?> pickTeam(
  BuildContext context,
  List<Team> teams, {
  int? disabledId,
  int? selectedId,
}) {
  return showModalBottomSheet<Team>(
    context: context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in teams)
              ListTile(
                enabled: t.id != disabledId,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  width: 8,
                  height: 36,
                  decoration: BoxDecoration(
                    color: teamColor(t.name),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(t.name, style: displayStyle(size: 28)),
                trailing: t.id == selectedId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// A finished match shown like a broadcast score strip.
class MatchStrip extends StatelessWidget {
  final MatchItem match;

  /// When set, a small trash button is shown to delete the match.
  final VoidCallback? onDelete;

  const MatchStrip({super.key, required this.match, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final homeColor = teamColor(match.homeTeamName);
    final awayColor = teamColor(match.awayTeamName);
    final homeWon = match.result == 'HOME_WIN';
    final awayWon = match.result == 'AWAY_WIN';

    Color nameColor(bool won, bool lost) =>
        lost ? AppColors.textDim : AppColors.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: homeColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            match.homeTeamName,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(
                              size: 24,
                              color: nameColor(homeWon, awayWon),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHi,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${match.homeGoals}',
                                style: displayStyle(
                                  size: 34,
                                  color: awayWon ? AppColors.textDim : AppColors.text,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('-', style: displayStyle(size: 26, color: AppColors.textDim)),
                              ),
                              Text(
                                '${match.awayGoals}',
                                style: displayStyle(
                                  size: 34,
                                  color: homeWon ? AppColors.textDim : AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            match.awayTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(
                              size: 24,
                              color: nameColor(awayWon, homeWon),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (match.goals.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Scorers(match.goalsOf(match.homeTeamName), TextAlign.right)),
                          const SizedBox(width: 40),
                          Expanded(child: _Scorers(match.goalsOf(match.awayTeamName), TextAlign.left)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDate(match.matchDate),
                          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              match.leagueName,
                              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                            ),
                            if (onDelete != null)
                              SizedBox(
                                width: 28,
                                height: 20,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  tooltip: 'Delete match',
                                  color: AppColors.textDim,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: onDelete,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 5, color: awayColor),
          ],
        ),
      ),
    );
  }
}

/// "Mbappé 2, Vinicius" under a match score.
class _Scorers extends StatelessWidget {
  final List<GoalItem> goals;
  final TextAlign align;

  const _Scorers(this.goals, this.align);

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    final text = goals
        .map((g) => g.goals > 1 ? '${g.playerName} ${g.goals}' : g.playerName)
        .join(', ');
    return Text(
      '⚽ $text',
      textAlign: align,
      style: const TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.3),
    );
  }
}
