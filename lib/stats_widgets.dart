import 'package:flutter/material.dart';

import 'models.dart';
import 'player_widgets.dart';
import 'theme.dart';

/// Section title used in stats pages.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? hint;

  const SectionTitle(this.text, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: displayStyle(size: 28)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Text(text, style: const TextStyle(color: AppColors.textDim, height: 1.4)),
      );
}

/// Ranking of top scorers.
class ScorerList extends StatelessWidget {
  final List<ScorerRow> rows;
  final int limit;

  const ScorerList({super.key, required this.rows, this.limit = 10});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyNote(
          'No scorers yet. When you save a match, add who scored and they will show up here.');
    }
    final shown = rows.take(limit).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}',
                        style: displayStyle(
                            size: 24,
                            color: i == 0
                                ? const Color(0xFFFFD166)
                                : (i == 1
                                    ? const Color(0xFFC9D1E6)
                                    : (i == 2 ? const Color(0xFFD58A4A) : AppColors.textDim)))),
                  ),
                  Container(
                    width: 4,
                    height: 30,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: teamColor(shown[i].teamName),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shown[i].player.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(shown[i].teamName,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('${shown[i].goals}',
                      style: displayStyle(size: 32, weight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  const Text('goals', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Players that appear in the most active squads.
class MostUsedList extends StatelessWidget {
  final List<MostUsedRow> rows;
  final int limit;

  const MostUsedList({super.key, required this.rows, this.limit = 10});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyNote(
          'Nobody yet. Build a squad for a team and mark it as active in Squads.');
    }
    final shown = rows.take(limit).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(),
            PlayerTile(
              player: shown[i].player,
              note: '${shown[i].squads} squad${shown[i].squads == 1 ? '' : 's'}',
              onTap: () => showPlayerDetail(context, shown[i].player),
            ),
          ],
        ],
      ),
    );
  }
}
