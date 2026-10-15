import 'package:flutter/material.dart';

import 'models.dart';
import 'player_widgets.dart';
import 'theme.dart';

/// Side by side comparison of two players (ratings, price and every attribute).
Future<void> showPlayerComparison(BuildContext context, Player a, Player b) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.92,
      child: _Comparison(a: a, b: b),
    ),
  );
}

class _Comparison extends StatelessWidget {
  final Player a;
  final Player b;

  const _Comparison({required this.a, required this.b});

  Widget _head(Player p) => Expanded(
        child: Column(
          children: [
            PlayerAvatar(player: p, size: 64),
            const SizedBox(height: 8),
            Text(p.shortName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(p.positions,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            Text(p.clubName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      );

  /// One row: value of A, label, value of B. The better value is highlighted.
  Widget _row(String label, num? va, num? vb,
      {String Function(num)? fmt, bool lowerIsBetter = false}) {
    if (va == null && vb == null) return const SizedBox.shrink();
    String text(num? v) => v == null ? '-' : (fmt != null ? fmt(v) : '${v.round()}');
    final better = (va == null || vb == null || va == vb)
        ? 0
        : ((va > vb) != lowerIsBetter ? -1 : 1); // -1 = A wins, 1 = B wins
    Widget cell(num? v, bool wins, TextAlign align) => Expanded(
          child: Text(
            text(v),
            textAlign: align,
            style: TextStyle(
              fontSize: wins ? 17 : 15,
              fontWeight: wins ? FontWeight.w900 : FontWeight.w500,
              color: wins ? const Color(0xFFFFD166) : AppColors.text,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          cell(va, better == -1, TextAlign.left),
          Expanded(
            flex: 2,
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
          cell(vb, better == 1, TextAlign.right),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text, style: displayStyle(size: 22)),
      );

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<StatDef>>{};
    for (final s in kStats) {
      if (a.stat(s.key) == null || b.stat(s.key) == null) continue;
      groups.putIfAbsent(s.group, () => []).add(s);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _head(a),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Text('VS', style: displayStyle(size: 24, color: AppColors.textDim)),
            ),
            _head(b),
          ],
        ),
        _title('Overview'),
        _row('Overall', a.overall, b.overall),
        _row('Potential', a.potential, b.potential),
        _row('Price', a.valueEur, b.valueEur, fmt: (v) => formatValue(v.round())),
        _row('Age', a.age, b.age, lowerIsBetter: true),
        _row('Height (cm)', a.heightCm, b.heightCm),
        _row('Weak foot', a.weakFoot, b.weakFoot),
        _row('Skill moves', a.skillMoves, b.skillMoves),
        for (final g in groups.entries) ...[
          _title(g.key),
          for (final s in g.value) _row(s.label, a.stat(s.key), b.stat(s.key)),
        ],
      ],
    );
  }
}
