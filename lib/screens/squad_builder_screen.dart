import 'package:flutter/material.dart';

import '../api.dart';
import '../formations.dart';
import '../models.dart';
import '../pitch.dart';
import '../player_widgets.dart';
import '../theme.dart';

/// Edit one squad: formation, starting XI on a pitch, and the bench.
/// Pops with `true` when something was saved or deleted.
class SquadBuilderScreen extends StatefulWidget {
  final Squad squad;

  const SquadBuilderScreen({super.key, required this.squad});

  @override
  State<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends State<SquadBuilderScreen> {
  late final TextEditingController _name;
  late String _formation;
  late Map<int, Player> _slots;
  late bool _active;
  bool _dirty = false;
  bool _saving = false;
  Set<int> _taken = {}; // players other teams already have in this league
  int? _budget; // league budget in millions of euros

  Squad get _original => widget.squad;
  bool get _isNew => _original.id == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _original.name);
    _formation = _original.formation;
    _slots = Map<int, Player>.from(_original.slots);
    _active = _original.active;
    Api.leagues().then((all) {
      for (final l in all) {
        if (l.id == _original.leagueId && mounted) setState(() => _budget = l.budgetMillions);
      }
    }).catchError((_) {});
    Api.takenPlayers(_original.leagueId, _original.teamId).then((ids) {
      if (mounted) setState(() => _taken = ids);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _change(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  Squad _draft() => Squad(
        id: _original.id,
        leagueId: _original.leagueId,
        teamId: _original.teamId,
        teamName: _original.teamName,
        leagueName: _original.leagueName,
        name: _name.text.trim(),
        formation: _formation,
        active: _active,
        slots: _slots,
      );

  Future<void> _chooseFormation() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Formation', style: displayStyle(size: 28)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in formations)
                    ChoiceChip(
                      label: Text(f.name),
                      selected: f.name == _formation,
                      showCheckmark: false,
                      selectedColor: AppColors.text,
                      backgroundColor: AppColors.surfaceHi,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: f.name == _formation ? AppColors.ink : AppColors.text,
                      ),
                      onSelected: (_) => Navigator.pop(ctx, f.name),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == _formation) return;
    _change(() {
      _slots = remapStarters(_slots, formationByName(_formation), formationByName(picked));
      _formation = picked;
    });
  }

  /// Swaps two places of the squad (either can be empty). Used by drag and drop.
  void _swap(int from, int to) {
    if (from == to) return;
    _change(() {
      final a = _slots[from];
      final b = _slots[to];
      if (b == null) {
        _slots.remove(from);
      } else {
        _slots[from] = b;
      }
      if (a == null) {
        _slots.remove(to);
      } else {
        _slots[to] = a;
      }
    });
  }

  Set<int> _usedIds({int? exceptSlot}) => {
        for (final e in _slots.entries)
          if (e.key != exceptSlot) e.value.id,
      };

  Future<void> _pickFor(int slot, String position) async {
    final player = await pickPlayer(
      context,
      initialPosition: position,
      excludeIds: _usedIds(exceptSlot: slot),
      takenIds: _taken,
      maxValueEur: _budget == null
          ? null
          : (_budget! * 1000000 -
                  _slots.entries
                      .where((e) => e.key != slot)
                      .fold<int>(0, (a, e) => a + (e.value.valueEur ?? 0)))
              .clamp(0, 1 << 40),
    );
    if (player == null) return;
    _change(() => _slots[slot] = player);
  }

  Future<void> _onSlotTap(int slot, String position) async {
    final current = _slots[slot];
    if (current == null) {
      return _pickFor(slot, position);
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerTile(player: current, onTap: () => Navigator.pop(ctx, 'info')),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change player'),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            if (slot < Squad.benchStart)
              ListTile(
                leading: const Icon(Icons.event_seat_outlined),
                title: const Text('Send to bench'),
                onTap: () => Navigator.pop(ctx, 'bench'),
              )
            else
              ListTile(
                leading: const Icon(Icons.sports_soccer),
                title: const Text('Swap with a starter'),
                onTap: () => Navigator.pop(ctx, 'swap'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Remove'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'info':
        await showPlayerDetail(context, current);
      case 'change':
        await _pickFor(slot, position);
      case 'remove':
        _change(() => _slots.remove(slot));
      case 'bench':
        _sendToBench(slot);
      case 'swap':
        await _swapWithStarter(slot);
    }
  }

  void _sendToBench(int slot) {
    for (var k = Squad.benchStart; k < Squad.benchStart + Squad.benchSize; k++) {
      if (!_slots.containsKey(k)) {
        _change(() => _slots[k] = _slots.remove(slot)!);
        return;
      }
    }
    _toast('The bench is full');
  }

  Future<void> _swapWithStarter(int benchSlot) async {
    final formation = formationByName(_formation);
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Swap with…', style: displayStyle(size: 28)),
              ),
              for (var i = 0; i < 11; i++)
                ListTile(
                  leading: SizedBox(
                    width: 44,
                    child: Text(formation.slots[i].position,
                        style: const TextStyle(
                            color: AppColors.textDim, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(_slots[i]?.shortName ?? 'Empty'),
                  trailing: _slots[i] == null ? null : OvrBadge(overall: _slots[i]!.overall, size: 32),
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (target == null) return;
    _change(() {
      final starter = _slots[target];
      _slots[target] = _slots[benchSlot]!;
      if (starter == null) {
        _slots.remove(benchSlot);
      } else {
        _slots[benchSlot] = starter;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _toast('Give the squad a name');
    if (_budget != null && _draft().totalValue > _budget! * 1000000) {
      return _toast('The squad is over the league budget of ${_budget}M. Replace some players.');
    }
    setState(() => _saving = true);
    try {
      await Api.saveSquad(_draft());
      if (!mounted) return;
      _dirty = false;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this squad?', style: displayStyle(size: 28)),
        content: Text('"${_original.name}" will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep squad')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete squad')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteSquad(_original.id!);
      if (!mounted) return;
      _dirty = false;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Discard changes?', style: displayStyle(size: 28)),
        content: const Text('You have unsaved changes in this squad.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final formation = formationByName(_formation);
    final draft = _draft();
    final teamColorValue = teamColor(_original.teamName);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          navigator.pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New squad' : 'Squad'),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Delete squad',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 36,
                  decoration: BoxDecoration(
                    color: teamColorValue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_original.teamName}  ·  ${_original.leagueName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(size: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              maxLength: 60,
              onChanged: (_) => _change(() {}),
              decoration: const InputDecoration(labelText: 'Squad name', counterText: ''),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseFormation,
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: Text(_formation),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const Spacer(),
                const Text('Saved as the current squad',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryRow(squad: draft, budgetMillions: _budget),
            const SizedBox(height: 12),
            Pitch(
              formation: formation,
              slots: _slots,
              onTap: (i) => _onSlotTap(i, formation.slots[i].position),
              onSwap: _swap,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Tip: hold a player and drag him onto another place to swap them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
            ),
            const SizedBox(height: 22),
            Text('Bench', style: displayStyle(size: 26)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var k = Squad.benchStart; k < Squad.benchStart + Squad.benchSize; k++)
                  DragSwapSlot(
                    index: k,
                    canDrag: _slots[k] != null,
                    onSwap: _swap,
                    width: 100,
                    height: 92,
                    child: _BenchSlot(
                      player: _slots[k],
                      onTap: () => _onSlotTap(k, ''),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                    )
                  : const Text('Save squad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Squad squad;
  final int? budgetMillions;

  const _SummaryRow({required this.squad, this.budgetMillions});

  Widget _box(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value, style: displayStyle(size: 26)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final starters = squad.starters.length;
    return Row(
      children: [
        _box('XI OVR', starters == 0 ? '-' : squad.averageOverall.toStringAsFixed(1)),
        const SizedBox(width: 8),
        _box(budgetMillions == null ? 'Squad value' : 'of ${budgetMillions}M budget',
            formatValue(squad.totalValue)),
        const SizedBox(width: 8),
        _box('Avg age', squad.slots.isEmpty ? '-' : squad.averageAge.toStringAsFixed(1)),
        const SizedBox(width: 8),
        _box('Starters', '$starters/11'),
      ],
    );
  }
}

class _BenchSlot extends StatelessWidget {
  final Player? player;
  final VoidCallback onTap;

  const _BenchSlot({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = player;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: p == null
            ? const SizedBox(
                height: 54,
                child: Center(child: Icon(Icons.add, color: AppColors.textDim)),
              )
            : Column(
                children: [
                  PlayerAvatar(player: p, size: 38),
                  const SizedBox(height: 4),
                  Text(p.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(p.mainPosition,
                      style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
                ],
              ),
      ),
    );
  }
}
