import 'package:flutter/material.dart';

import 'formations.dart';
import 'models.dart';
import 'pitch.dart';
import 'theme.dart';

/// Picks the best XI for a formation from the rated players: slots with fewer
/// possible players are filled first, each with the highest rated one left.
/// Slots nobody can fill stay empty.
Map<int, RatingRow> buildBestXi(Formation formation, List<RatingRow> rows) {
  final rated = rows.where((r) => r.rating != null).toList()
    ..sort((a, b) => b.rating!.compareTo(a.rating!));

  final order = List<int>.generate(11, (i) => i)
    ..sort((a, b) {
      int fits(int slot) => rated
          .where((r) => fitsSlot(r.player, formation.slots[slot].position))
          .length;
      return fits(a).compareTo(fits(b));
    });

  final result = <int, RatingRow>{};
  final used = <int>{};
  for (final slot in order) {
    final position = formation.slots[slot].position;
    for (final r in rated) {
      if (used.contains(r.player.id)) continue;
      if (!fitsSlot(r.player, position)) continue;
      result[slot] = r;
      used.add(r.player.id);
      break;
    }
  }
  return result;
}

String formatRating(double r) =>
    r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

/// A pitch with the best XI of the given ratings and a formation selector.
class BestXiView extends StatefulWidget {
  final List<RatingRow> rows;
  final String emptyMessage;

  const BestXiView({super.key, required this.rows, required this.emptyMessage});

  @override
  State<BestXiView> createState() => _BestXiViewState();
}

class _BestXiViewState extends State<BestXiView> {
  String _formation = '4-3-3';

  @override
  Widget build(BuildContext context) {
    final formation = formationByName(_formation);
    final xi = buildBestXi(formation, widget.rows);
    final ratedCount = widget.rows.where((r) => r.rating != null).length;

    if (ratedCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textDim, height: 1.4),
        ),
      );
    }

    final average = xi.isEmpty
        ? 0.0
        : xi.values.fold<double>(0, (a, r) => a + r.rating!) / xi.length;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in formations)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.name),
                    selected: f.name == _formation,
                    showCheckmark: false,
                    selectedColor: AppColors.text,
                    backgroundColor: AppColors.surfaceHi,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: f.name == _formation ? AppColors.ink : AppColors.text,
                    ),
                    onSelected: (_) => setState(() => _formation = f.name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Pitch(
          formation: formation,
          slots: {for (final e in xi.entries) e.key: e.value.player},
          tags: {for (final e in xi.entries) e.key: formatRating(e.value.rating!)},
        ),
        const SizedBox(height: 10),
        Text(
          xi.length < 11
              ? 'Only ${xi.length} of 11 places can be filled with the rated players.'
              : 'Average rating ${average.toStringAsFixed(2)}',
          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
      ],
    );
  }
}
