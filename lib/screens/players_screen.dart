import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../player_compare.dart';
import '../player_filters.dart';
import '../player_widgets.dart';
import '../theme.dart';
import '../widgets.dart';

const List<String> _positions = [
  'GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'CDM', 'CM', 'CAM',
  'LM', 'RM', 'LW', 'RW', 'CF', 'ST',
];

/// Browse the whole player database with filters and compare two players.
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _request = 0;

  String _position = '';
  PlayerFilters _filters = PlayerFilters();
  final List<Player> _players = [];
  final List<Player> _compare = [];
  int _page = 0;
  int _total = 0;
  bool _hasNext = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400 &&
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
    if (reset) _page = 0;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _players.clear();
    });
    try {
      final result = await Api.searchPlayers(
        q: _search.text.trim(),
        position: _position,
        filters: _filters,
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

  void _toggleCompare(Player p) {
    setState(() {
      final i = _compare.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        _compare.removeAt(i);
      } else {
        if (_compare.length == 2) _compare.removeAt(0);
        _compare.add(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce =
                        Timer(const Duration(milliseconds: 350), () => _load(reset: true));
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search a player or club',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _filters.activeCount > 0,
                label: Text('${_filters.activeCount}'),
                child: IconButton.filledTonal(
                  tooltip: 'Filters',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final result = await showPlayerFilters(context, _filters);
                    if (result == null) return;
                    _filters = result;
                    _load(reset: true);
                  },
                ),
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
              for (final pos in ['', ..._positions])
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _loading && _players.isEmpty
                  ? ''
                  : '$_total players  ·  sorted by ${sortLabel(_filters.sort).toLowerCase()}'
                      '${_filters.ascending ? ' (low to high)' : ''}'
                      '  ·  tap the icon to compare',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ),
        ),
        Expanded(child: _body()),
        if (_compare.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _compare.map((p) => p.shortName).join('  vs  ') +
                          (_compare.length == 1 ? '  (pick another)' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_compare.clear),
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: _compare.length == 2
                        ? () => showPlayerComparison(context, _compare[0], _compare[1])
                        : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(110, 42)),
                    child: const Text('Compare'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _body() {
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_players.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_players.isEmpty) {
      return const EmptyView(
        title: 'No players found',
        message: 'Try another name or remove some filters.',
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
        final picked = _compare.any((x) => x.id == p.id);
        return PlayerTile(
          player: p,
          onTap: () => showPlayerDetail(context, p),
          trailingOverride: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatValue(p.valueEur),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('POT ${p.potential}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                ],
              ),
              IconButton(
                tooltip: picked ? 'Remove from comparison' : 'Compare',
                icon: Icon(
                  picked ? Icons.check_circle : Icons.compare_arrows,
                  color: picked ? const Color(0xFFFFD166) : AppColors.textDim,
                ),
                onPressed: () => _toggleCompare(p),
              ),
            ],
          ),
        );
      },
    );
  }
}
