import 'models.dart';

/// Formations and where each slot sits on the pitch.
///
/// Slot order matters: it is what the backend stores. Slot 0 is always the
/// goalkeeper, then defenders, midfielders and forwards, each row from left to
/// right. Slots 11 and up are the bench (see Squad.benchStart).
class SlotSpec {
  final String position; // GK, LB, CB, RB, CDM, CM, CAM, LM, RM, LW, RW, ST ...
  final double x; // 0 = left, 1 = right
  final double y; // 0 = opponent goal, 1 = own goal

  const SlotSpec(this.position, this.x, this.y);
}

class Formation {
  final String name;
  final List<SlotSpec> slots;

  const Formation(this.name, this.slots);
}

Formation _build(String name, List<List<String>> rows) {
  final slots = <SlotSpec>[const SlotSpec('GK', 0.5, 0.92)];
  const top = 0.12;
  const bottom = 0.74;
  for (var r = 0; r < rows.length; r++) {
    final y = rows.length == 1
        ? (top + bottom) / 2
        : bottom - r * (bottom - top) / (rows.length - 1);
    final xs = _rowX(rows[r]);
    for (var i = 0; i < rows[r].length; i++) {
      slots.add(SlotSpec(rows[r][i], xs[i], y));
    }
  }
  assert(slots.length == 11, 'Formation $name must have 11 players');
  return Formation(name, slots);
}

/// Wide players (L* / R*) go to the touchlines; the others are spread around the
/// centre, so a pair of defensive midfielders is never out on the wing.
List<double> _rowX(List<String> row) {
  bool left(String p) => p.startsWith('L');
  bool right(String p) => p.startsWith('R');
  final wide = row.where((p) => left(p) || right(p)).length;
  final centres = row.length - wide;
  final step = switch (centres) {
    1 => 0.0,
    2 => wide > 0 ? 0.24 : 0.28,
    3 => wide > 0 ? 0.24 : 0.26,
    4 => 0.22,
    _ => 0.2,
  };
  var c = 0;
  return [
    for (final p in row)
      if (left(p))
        0.09
      else if (right(p))
        0.91
      else
        0.5 + (c++ - (centres - 1) / 2) * step,
  ];
}

final List<Formation> formations = [
  _build('4-3-3', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CM', 'CM', 'CM'],
    ['LW', 'ST', 'RW'],
  ]),
  _build('4-4-2', [
    ['LB', 'CB', 'CB', 'RB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['ST', 'ST'],
  ]),
  _build('4-2-3-1', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM', 'CDM'],
    ['LM', 'CAM', 'RM'],
    ['ST'],
  ]),
  _build('4-1-4-1', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM'],
    ['LM', 'CM', 'CM', 'RM'],
    ['ST'],
  ]),
  _build('4-3-2-1', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CM', 'CM', 'CM'],
    ['CAM', 'CAM'],
    ['ST'],
  ]),
  _build('4-1-2-1-2', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM'],
    ['CM', 'CM'],
    ['CAM'],
    ['ST', 'ST'],
  ]),
  _build('4-4-1-1', [
    ['LB', 'CB', 'CB', 'RB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['CAM'],
    ['ST'],
  ]),
  _build('4-5-1', [
    ['LB', 'CB', 'CB', 'RB'],
    ['LM', 'CM', 'CAM', 'CM', 'RM'],
    ['ST'],
  ]),
  _build('4-2-2-2', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM', 'CDM'],
    ['CAM', 'CAM'],
    ['ST', 'ST'],
  ]),
  _build('4-2-1-3', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM', 'CDM'],
    ['CAM'],
    ['LW', 'ST', 'RW'],
  ]),
  _build('4-2-4', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CM', 'CM'],
    ['LW', 'ST', 'ST', 'RW'],
  ]),
  _build('4-3-1-2', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CM', 'CM', 'CM'],
    ['CAM'],
    ['ST', 'ST'],
  ]),
  _build('4-1-3-2', [
    ['LB', 'CB', 'CB', 'RB'],
    ['CDM'],
    ['LM', 'CM', 'RM'],
    ['ST', 'ST'],
  ]),
  _build('3-5-2', [
    ['CB', 'CB', 'CB'],
    ['LM', 'CDM', 'CAM', 'CDM', 'RM'],
    ['ST', 'ST'],
  ]),
  _build('3-4-3', [
    ['CB', 'CB', 'CB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['LW', 'ST', 'RW'],
  ]),
  _build('3-4-1-2', [
    ['CB', 'CB', 'CB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['CAM'],
    ['ST', 'ST'],
  ]),
  _build('3-4-2-1', [
    ['CB', 'CB', 'CB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['CAM', 'CAM'],
    ['ST'],
  ]),
  _build('3-1-4-2', [
    ['CB', 'CB', 'CB'],
    ['CDM'],
    ['LM', 'CM', 'CM', 'RM'],
    ['ST', 'ST'],
  ]),
  _build('5-3-2', [
    ['LWB', 'CB', 'CB', 'CB', 'RWB'],
    ['CM', 'CM', 'CM'],
    ['ST', 'ST'],
  ]),
  _build('5-4-1', [
    ['LWB', 'CB', 'CB', 'CB', 'RWB'],
    ['LM', 'CM', 'CM', 'RM'],
    ['ST'],
  ]),
  _build('5-2-1-2', [
    ['LWB', 'CB', 'CB', 'CB', 'RWB'],
    ['CM', 'CM'],
    ['CAM'],
    ['ST', 'ST'],
  ]),
  _build('5-2-3', [
    ['LWB', 'CB', 'CB', 'CB', 'RWB'],
    ['CM', 'CM'],
    ['LW', 'ST', 'RW'],
  ]),
];

Formation formationByName(String name) =>
    formations.firstWhere((f) => f.name == name, orElse: () => formations.first);

/// When the formation changes, keep as many starters as possible: first in a
/// slot with the same position, then in any free slot.
Map<int, Player> remapStarters(
  Map<int, Player> slots,
  Formation from,
  Formation to,
) {
  final result = <int, Player>{};
  final loose = <Player>[];
  final taken = <int>{};

  // 1) Same position keeps its place.
  for (var i = 0; i < 11; i++) {
    final player = slots[i];
    if (player == null) continue;
    final label = from.slots[i].position;
    var placed = false;
    for (var j = 0; j < 11 && !placed; j++) {
      if (!taken.contains(j) && to.slots[j].position == label) {
        result[j] = player;
        taken.add(j);
        placed = true;
      }
    }
    if (!placed) loose.add(player);
  }
  // 2) The rest goes to free slots (not the goalkeeper's unless it is a keeper).
  final overflow = <Player>[];
  for (final player in loose) {
    var placed = false;
    for (var j = 0; j < 11 && !placed; j++) {
      if (taken.contains(j)) continue;
      final isKeeperSlot = to.slots[j].position == 'GK';
      if (isKeeperSlot != player.isGoalkeeper) continue;
      result[j] = player;
      taken.add(j);
      placed = true;
    }
    if (!placed) overflow.add(player);
  }
  // The bench stays as it is; starters that found no place go to free bench slots.
  slots.forEach((k, v) {
    if (k >= Squad.benchStart) result[k] = v;
  });
  for (final player in overflow) {
    for (var k = Squad.benchStart; k < Squad.benchStart + Squad.benchSize; k++) {
      if (!result.containsKey(k)) {
        result[k] = player;
        break;
      }
    }
  }
  return result;
}

const Map<String, List<String>> _compatible = {
  'LM': ['LW'],
  'RM': ['RW'],
  'LW': ['LM'],
  'RW': ['RM'],
  'LWB': ['LB'],
  'RWB': ['RB'],
  'LB': ['LWB'],
  'RB': ['RWB'],
  'CF': ['ST'],
  'ST': ['CF'],
};

/// Whether a player is used in a natural (or very close) position.
bool fitsSlot(Player player, String slotPosition) {
  if (player.canPlay(slotPosition)) return true;
  return (_compatible[slotPosition] ?? const []).any(player.canPlay);
}
