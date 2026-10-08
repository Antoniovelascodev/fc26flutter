import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

// Column widths. Kept tight so all columns fit on a 360px-wide phone.
const double _wPos = 20;
const double _wMark = 10;
const double _wStat = 24;
const double _wDiff = 32;
const double _wPts = 38;

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<RankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.ranking();
    dataVersion.addListener(_reload);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = Api.ranking();
    });
  }

  Future<void> _onRefresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The error is shown by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: _reload);
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return const EmptyView(
            title: 'No results yet',
            message: 'Save the first match in New match and the table starts here.',
          );
        }
      

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeagueTable(entries: entries),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 14, 10, 0),
                        child: Text(
                          'P -> Played\nW -> Won\nD -> Drawn\nL -> Lost\nGF -> Goals Favor\nGA -> Goals Against\nGD -> Goal Difference',
                          style: TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeagueTable extends StatelessWidget {
  final List<RankingEntry> entries;

  const _LeagueTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const _HeaderRow(),
          for (var i = 0; i < entries.length; i++) ...[
            const Divider(height: 1),
            _DataRow(position: i + 1, entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

TextStyle get _headerStyle => const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textDim,
    );

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  Widget _h(String label, double width, {bool strong = false}) => SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: strong
              ? _headerStyle.copyWith(color: AppColors.text, fontWeight: FontWeight.w800)
              : _headerStyle,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(
        children: [
          const SizedBox(width: _wPos + _wMark),
          Expanded(child: Text('Team', style: _headerStyle)),
          _h('P', _wStat),
          _h('W', _wStat),
          _h('D', _wStat),
          _h('L', _wStat),
          _h('GF', _wStat),
          _h('GA', _wStat),
          _h('GD', _wDiff),
          _h('Pts', _wPts, strong: true),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final int position;
  final RankingEntry entry;

  const _DataRow({required this.position, required this.entry});

  Widget _num(Object value, double width, {Color color = AppColors.text}) {
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leader = position == 1;
    final color = teamColor(entry.teamName);
    final gd = entry.goalDifference;
    final gdText = gd > 0 ? '+$gd' : '$gd';

    return Container(
      color: leader ? teamWash(color, strength: 40) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: _wPos,
            child: Text(
              '$position',
              style: displayStyle(
                size: 24,
                color: leader ? AppColors.text : AppColors.textDim,
              ),
            ),
          ),
          SizedBox(
            width: _wMark,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayStyle(size: 25),
            ),
          ),
          _num(entry.matchesPlayed, _wStat),
          _num(entry.wins, _wStat),
          _num(entry.draws, _wStat),
          _num(entry.losses, _wStat),
          _num(entry.goalsFor, _wStat),
          _num(entry.goalsAgainst, _wStat),
          _num(gdText, _wDiff, color: gd < 0 ? AppColors.textDim : AppColors.text),
          SizedBox(
            width: _wPts,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${entry.points}',
                style: displayStyle(size: 28, weight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
