import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Card color by overall rating (roughly like the game's tiers).
Color ratingColor(int overall) {
  if (overall >= 90) return const Color(0xFFFFD166);
  if (overall >= 85) return const Color(0xFF9BE564);
  if (overall >= 75) return const Color(0xFF35E0B0);
  if (overall >= 65) return const Color(0xFF4C8DFF);
  return AppColors.draw;
}

/// Square badge with the overall rating.
class OvrBadge extends StatelessWidget {
  final int overall;
  final double size;

  const OvrBadge({super.key, required this.overall, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ratingColor(overall),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        '$overall',
        style: displayStyle(size: size * 0.62, weight: FontWeight.w900, color: AppColors.ink),
      ),
    );
  }
}

/// One row of a player list.
class PlayerTile extends StatelessWidget {
  final Player player;
  final VoidCallback? onTap;
  final String? note;

  const PlayerTile({super.key, required this.player, this.onTap, this.note});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: OvrBadge(overall: player.overall),
        title: Text(
          player.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            player.positions,
            if (player.clubName.isNotEmpty) player.clubName,
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatValue(player.valueEur),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(note ?? 'POT ${player.potential}',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Full details of a player in a bottom sheet.
Future<void> showPlayerDetail(BuildContext context, Player p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OvrBadge(overall: p.overall, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.shortName, style: displayStyle(size: 30)),
                      const SizedBox(height: 2),
                      Text(
                        p.longName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(p.positions, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip('Value', formatValue(p.valueEur)),
                _InfoChip('Potential', '${p.potential}'),
                if (p.age != null) _InfoChip('Age', '${p.age}'),
                if (p.heightCm != null) _InfoChip('Height', '${p.heightCm} cm'),
                if (p.preferredFoot.isNotEmpty) _InfoChip('Foot', p.preferredFoot),
                if (p.weakFoot != null) _InfoChip('Weak foot', '${p.weakFoot}★'),
                if (p.skillMoves != null) _InfoChip('Skills', '${p.skillMoves}★'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              [p.clubName, p.leagueName, p.nationalityName]
                  .where((e) => e.isNotEmpty)
                  .join('  ·  '),
              style: const TextStyle(color: AppColors.textDim),
            ),
            const SizedBox(height: 18),
            for (final s in p.headlineStats) _StatBar(label: s.$1, value: s.$2),
          ],
        ),
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int? value;

  const _StatBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
          SizedBox(
            width: 30,
            child: Text(value == null ? '-' : '$v',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 8,
                backgroundColor: AppColors.line,
                color: ratingColor(v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _positionFilters = [
  'GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'CDM', 'CM', 'CAM',
  'LM', 'RM', 'LW', 'RW', 'CF', 'ST',
];

/// Search the player database and pick one. Returns null if dismissed.
///
/// [initialPosition] pre-selects the position filter (the slot being filled);
/// players in [excludeIds] are shown greyed out.
Future<Player?> pickPlayer(
  BuildContext context, {
  String initialPosition = '',
  Set<int> excludeIds = const {},
}) {
  return showModalBottomSheet<Player>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.92,
      child: _PlayerPicker(initialPosition: initialPosition, excludeIds: excludeIds),
    ),
  );
}

class _PlayerPicker extends StatefulWidget {
  final String initialPosition;
  final Set<int> excludeIds;

  const _PlayerPicker({required this.initialPosition, required this.excludeIds});

  @override
  State<_PlayerPicker> createState() => _PlayerPickerState();
}

class _PlayerPickerState extends State<_PlayerPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _request = 0;

  late String _position = widget.initialPosition;
  String _sort = 'overall';
  final List<Player> _players = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = true;
  Object? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 &&
          _hasNext &&
          !_loading) {
        _load(reset: false);
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final id = ++_request;
    if (reset) {
      _page = 0;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _players.clear();
    });
    try {
      final result = await Api.searchPlayers(
        q: _search.text.trim(),
        position: _position,
        sort: _sort,
        page: _page,
      );
      if (!mounted || id != _request) return;
      setState(() {
        _players.addAll(result.players);
        _hasNext = result.hasNext;
        _total = result.total;
        _page++;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _onTextChanged,
                    decoration: const InputDecoration(
                      hintText: 'Name or club (e.g. "mbappe", "real madrid")',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) {
                    _sort = v;
                    _load(reset: true);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'overall', child: Text('Best rating')),
                    PopupMenuItem(value: 'value', child: Text('Highest value')),
                    PopupMenuItem(value: 'potential', child: Text('Best potential')),
                    PopupMenuItem(value: 'age', child: Text('Youngest')),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // The position of the slot being filled comes first so it is visible.
                for (final pos in [
                  '',
                  if (widget.initialPosition.isNotEmpty) widget.initialPosition,
                  ..._positionFilters.where((p) => p != widget.initialPosition),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(pos.isEmpty ? 'All' : pos),
                      selected: _position == pos,
                      showCheckmark: false,
                      selectedColor: AppColors.text,
                      backgroundColor: AppColors.surfaceHi,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _position == pos ? AppColors.ink : AppColors.text,
                      ),
                      onSelected: (_) {
                        _position = pos;
                        _load(reset: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total players',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ),
            ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_players.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_players.isEmpty) {
      return const EmptyView(
        title: 'No players found',
        message: 'Try another name, or remove the position filter. '
            'If the database is empty, import the players CSV first.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _players.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _players.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final p = _players[i];
        final taken = widget.excludeIds.contains(p.id);
        return PlayerTile(
          player: p,
          note: taken ? 'In squad' : null,
          onTap: taken ? null : () => Navigator.pop(context, p),
        );
      },
    );
  }
}
