import 'package:flutter/material.dart';

import '../api.dart';
import '../async_view.dart';
import '../best_xi.dart';
import '../stats_widgets.dart';
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
  List<RankingEntry>? _cached;

  @override
  void initState() {
    super.initState();
    _future = Api.ranking();
    Api.cachedRanking().then((c) {
      if (mounted) setState(() => _cached = c);
    });
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
        final loading = snap.connectionState != ConnectionState.done;
        if (loading && (_cached == null || _cached!.isEmpty)) {
          return const SkeletonList(rows: 4);
        }
        if (!loading && snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: _reload);
        }
        final entries = loading ? _cached! : snap.data!;
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
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeaderCard(entry: entries.first),
                      const SizedBox(height: 12),
                      LeagueTable(entries: entries),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 14, 10, 0),
                        child: Text(
                          'P played · W won · D drawn · L lost · GF goals for · GA goals against · GD goal difference',
                          style: TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.4),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: _MegaStats(),
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

class LeagueTable extends StatelessWidget {
  final List<RankingEntry> entries;

  const LeagueTable({super.key, required this.entries});

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
                color: switch (position) {
                  1 => const Color(0xFFFFD166),
                  2 => const Color(0xFFD5DBE8),
                  3 => const Color(0xFFD99A6C),
                  _ => AppColors.textDim,
                },
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

/// Stats of the whole MegaLeague: scorers, most used players and best XI.
class _MegaStats extends StatelessWidget {
  const _MegaStats();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Top scorers', hint: 'All leagues together'),
        AsyncView<List<ScorerRow>>(
          compact: true,
          load: () => Api.topScorers(),
          builder: (context, rows) => ScorerList(rows: rows),
        ),
        const SectionTitle('Most used players', hint: 'In the active squads of every league'),
        AsyncView<List<MostUsedRow>>(
          compact: true,
          load: () => Api.mostUsed(),
          builder: (context, rows) => MostUsedList(rows: rows),
        ),
        const SectionTitle('MegaLeague best XI',
            hint: 'Average of the ratings given in each league'),
        AsyncView<List<RatingRow>>(
          compact: true,
          load: () => Api.megaRatings(),
          builder: (context, rows) => BestXiView(
            rows: rows,
            emptyMessage: 'Mark the players after each match ("How did they play?") '
                'and the MegaLeague best XI appears here.',
          ),
        ),
      ],
    );
  }
}

/// The team at the top of the table, shown big.
class _LeaderCard extends StatelessWidget {
  final RankingEntry entry;

  const _LeaderCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = teamColor(entry.teamName);
    final gd = entry.goalDifference;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(120), AppColors.surface],
        ),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, size: 16, color: Color(0xFFFFD166)),
                    const SizedBox(width: 6),
                    const Text('LEADER',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textDim)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(entry.teamName, style: displayStyle(size: 40)),
                const SizedBox(height: 4),
                Text(
                  '${entry.matchesPlayed} played  ·  ${entry.wins}W ${entry.draws}D ${entry.losses}L'
                  '  ·  GD ${gd > 0 ? '+' : ''}$gd',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('${entry.points}', style: displayStyle(size: 64, weight: FontWeight.w900)),
              const Text('PTS', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
