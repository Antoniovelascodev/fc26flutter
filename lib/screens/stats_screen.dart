import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../models.dart';
import '../stats_calc.dart';
import '../stats_widgets.dart';
import '../theme.dart';
import '../widgets.dart';

const _winColor = Color(0xFF2ECC71);
const _drawColor = Color(0xFF6D79AB);
const _lossColor = Color(0xFFF2463C);

/// Small colored dots with the latest results (oldest -> newest).
class FormDots extends StatelessWidget {
  final List<String> results;
  final double size;

  const FormDots(this.results, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in results)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r == 'W' ? _winColor : (r == 'L' ? _lossColor : _drawColor),
            ),
          ),
      ],
    );
  }
}

/// Numbers and records of the leagues: team profiles, form, records, MVPs and
/// how many matches each pair of friends still has to play.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<League> _leagues = [];
  List<Team> _teams = [];
  final Map<int, List<MatchItem>> _matches = {};
  int? _leagueId; // null = all leagues
  int _pairTarget = 2; // matches each pair should play in a league
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTarget();
    dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _loadTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('pair_target');
      if (saved != null && saved >= 1 && saved <= 6 && mounted) {
        setState(() => _pairTarget = saved);
      }
    } catch (_) {
      // Not important.
    }
  }

  Future<void> _setTarget(int n) async {
    setState(() => _pairTarget = n);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pair_target', n);
    } catch (_) {
      // Not important.
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.teams(), Api.leagues()]);
      final leagues = results[1] as List<League>;
      final lists = await Future.wait(leagues.map((l) => Api.matchesByLeague(l.id)));
      if (!mounted) return;
      setState(() {
        _teams = results[0] as List<Team>;
        _leagues = leagues;
        _matches
          ..clear()
          ..addEntries([for (var i = 0; i < leagues.length; i++) MapEntry(leagues[i].id, lists[i])]);
        if (_leagueId != null && !leagues.any((l) => l.id == _leagueId)) _leagueId = null;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<MatchItem> get _current => _leagueId == null
      ? [for (final l in _matches.values) ...l]
      : (_matches[_leagueId] ?? const []);

  Widget _chips() {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.text,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.line),
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.ink : AppColors.text,
            ),
            onSelected: (_) => onTap(),
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All leagues', _leagueId == null, () => setState(() => _leagueId = null)),
          for (final l in _leagues)
            chip(l.name, _leagueId == l.id, () => setState(() => _leagueId = l.id)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);
    final matches = _current;
    final names = <String>{
      ..._teams.map((t) => t.name),
      for (final m in matches) ...[m.homeTeamName, m.awayTeamName],
    };
    final profiles = [for (final n in names) profileOf(n, matches)]
      ..sort((a, b) {
        final pa = a.wins * 3 + a.draws;
        final pb = b.wins * 3 + b.draws;
        return pb != pa ? pb.compareTo(pa) : b.goalsFor.compareTo(a.goalsFor);
      });

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _chips(),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: matches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyView(
                        title: 'No matches yet',
                        message: 'Save some matches and the numbers and records appear here.',
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Teams', hint: 'Form = last 5 results, oldest to newest'),
                        for (final p in profiles) _TeamCard(p),
                        ..._records(matches),
                        if (_leagueId != null) ..._progress(matches),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- records ----

  List<Widget> _records(List<MatchItem> matches) {
    final r = computeRecords(matches);
    String score(MatchItem m) =>
        '${m.homeTeamName} ${m.homeGoals}-${m.awayGoals} ${m.awayTeamName}';
    final rows = <Widget>[
      if (r.biggestWin != null)
        _RecordRow(Icons.local_fire_department, 'Biggest win', score(r.biggestWin!)),
      if (r.mostGoals != null)
        _RecordRow(Icons.sports_soccer, 'Most goals in a match', score(r.mostGoals!)),
      if (r.longestWinning != null && r.longestWinning!.length >= 2)
        _RecordRow(Icons.trending_up, 'Longest winning streak',
            '${r.longestWinning!.team}: ${r.longestWinning!.length} in a row'),
      if (r.longestUnbeaten != null && r.longestUnbeaten!.length >= 2)
        _RecordRow(Icons.shield_outlined, 'Longest unbeaten run',
            '${r.longestUnbeaten!.team}: ${r.longestUnbeaten!.length} matches'),
    ];
    return [
      const SectionTitle('Records'),
      if (rows.isEmpty)
        const Text('Not enough matches yet.', style: TextStyle(color: AppColors.textDim))
      else
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: rows),
        ),
      if (r.mvps.isNotEmpty) ...[
        const SectionTitle('MVPs', hint: 'Best marked player of each match'),
        _PlayerList(
          [
            for (final a in r.mvps.take(5))
              (a.playerName, a.teamName, '${a.count} MVP${a.count == 1 ? '' : 's'}'),
          ],
        ),
      ],
      if (r.bestAverages.isNotEmpty) ...[
        const SectionTitle('Best average mark', hint: 'At least 2 rated matches'),
        _PlayerList(
          [
            for (final a in r.bestAverages.take(5))
              (a.playerName, a.teamName, '${a.average.toStringAsFixed(2)}  (${a.count})'),
          ],
        ),
      ],
    ];
  }

  // ---- progress of the league ----

  List<Widget> _progress(List<MatchItem> matches) {
    final names = <String>{
      ..._teams.map((t) => t.name),
      for (final m in matches) ...[m.homeTeamName, m.awayTeamName],
    }.toList()
      ..sort();
    if (names.length < 2) return const [];
    final counts = pairCounts(matches);
    final pairs = <(String, String)>[
      for (var i = 0; i < names.length; i++)
        for (var j = i + 1; j < names.length; j++) (names[i], names[j]),
    ];
    var played = 0;
    for (final p in pairs) {
      final c = counts[pairKey(p.$1, p.$2)] ?? 0;
      played += c > _pairTarget ? _pairTarget : c;
    }
    final total = pairs.length * _pairTarget;
    return [
      const SectionTitle('League progress', hint: 'Matches played between every pair'),
      Row(
        children: [
          const Text('Each pair plays', style: TextStyle(color: AppColors.textDim)),
          const SizedBox(width: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 2, label: Text('2x')),
              ButtonSegment(value: 3, label: Text('3x')),
            ],
            selected: {_pairTarget.clamp(1, 3)},
            onSelectionChanged: (s) => _setTarget(s.first),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : played / total,
          minHeight: 10,
          backgroundColor: AppColors.surfaceHi,
        ),
      ),
      const SizedBox(height: 6),
      Text('$played of $total matches played',
          style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            for (final p in pairs)
              _PairRow(
                a: p.$1,
                b: p.$2,
                played: counts[pairKey(p.$1, p.$2)] ?? 0,
                target: _pairTarget,
              ),
          ],
        ),
      ),
    ];
  }
}

class _TeamCard extends StatelessWidget {
  final TeamProfile p;

  const _TeamCard(this.p);

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, style: displayStyle(size: 22)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final color = teamColor(p.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: teamWash(color, strength: 34),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.name, style: displayStyle(size: 28))),
              if (p.results.isNotEmpty) FormDots(p.form()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('PLAYED', '${p.played}'),
              _stat('W-D-L', '${p.wins}-${p.draws}-${p.losses}'),
              _stat('WIN %', '${(p.winRate * 100).round()}'),
              _stat('GOALS/M', p.goalsForPerMatch.toStringAsFixed(1)),
              _stat('AGAINST/M', p.goalsAgainstPerMatch.toStringAsFixed(1)),
            ],
          ),
          if (p.played > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${p.cleanSheets} clean sheet${p.cleanSheets == 1 ? '' : 's'}'
              '${p.unbeaten >= 2 ? '  ·  ${p.unbeaten} unbeaten' : ''}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RecordRow(this.icon, this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFFD166)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  final List<(String, String, String)> rows; // name, team, value

  const _PlayerList(this.rows);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}',
                        style: displayStyle(size: 22, color: AppColors.textDim)),
                  ),
                  Container(
                    width: 4,
                    height: 26,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: teamColor(rows[i].$2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(rows[i].$2,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(rows[i].$3, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PairRow extends StatelessWidget {
  final String a;
  final String b;
  final int played;
  final int target;

  const _PairRow({required this.a, required this.b, required this.played, required this.target});

  @override
  Widget build(BuildContext context) {
    final done = played >= target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: teamColor(a)),
          ),
          const SizedBox(width: 6),
          Text(a, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('vs', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: teamColor(b)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(b, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$played / $target',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: done ? _winColor : AppColors.text)),
          if (done) const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.check_circle, size: 16, color: _winColor),
          ),
        ],
      ),
    );
  }
}
