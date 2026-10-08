import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

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
        // Every match is counted once per team, so the total is halved.
        final matchCount =
            entries.fold<int>(0, (sum, e) => sum + e.matchesPlayed) ~/ 2;

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: entries.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 2),
                  child: Text(
                    matchCount == 1 ? '1 match played' : '$matchCount matches played',
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                );
              }
              return _TableRow(position: i, entry: entries[i - 1]);
            },
          ),
        );
      },
    );
  }
}

class _TableRow extends StatelessWidget {
  final int position;
  final RankingEntry entry;

  const _TableRow({required this.position, required this.entry});

  @override
  Widget build(BuildContext context) {
    final leader = position == 1;
    final color = teamColor(entry.teamName);
    final gd = entry.goalDifference;
    final gdText = gd > 0 ? '+$gd' : '$gd';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: leader ? teamWash(color) : AppColors.surface,
        borderRadius: BorderRadius.circular(leader ? 22 : 14),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: leader ? 9 : 5, color: color),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, leader ? 18 : 12, 16, leader ? 18 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: leader ? 38 : 30,
                      child: Text(
                        '$position',
                        style: displayStyle(
                          size: leader ? 44 : 30,
                          color: leader ? AppColors.text : AppColors.textDim,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(size: leader ? 38 : 27),
                          ),
                          SizedBox(height: leader ? 10 : 8),
                          RecordBar(
                            wins: entry.wins,
                            draws: entry.draws,
                            losses: entry.losses,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 2,
                            children: [
                              _Stat(entry.matchesPlayed, 'played'),
                              _Stat(entry.wins, 'won'),
                              _Stat(entry.draws, 'drawn'),
                              _Stat(entry.losses, 'lost'),
                              _Stat(gdText, 'goal diff'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.points}',
                          style: displayStyle(size: leader ? 72 : 44, weight: FontWeight.w900),
                        ),
                        const Text(
                          'pts',
                          style: TextStyle(fontSize: 12, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final Object value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          TextSpan(text: label, style: const TextStyle(color: AppColors.textDim)),
        ],
      ),
      style: const TextStyle(fontSize: 12),
    );
  }
}
