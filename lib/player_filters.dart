import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// Every optional filter of the player search. Null / empty = not filtered.
class PlayerFilters {
  double? minValueM; // price in millions of euros
  double? maxValueM;
  int? minOverall;
  int? maxOverall;
  int? minPotential;
  int? minAge;
  int? maxAge;
  int? minHeight;
  int? maxHeight;
  String foot = ''; // '', 'Left', 'Right'
  int? minWeakFoot;
  int? minSkillMoves;
  String league = '';
  String nationality = '';
  Map<String, int> stats = {}; // attribute key -> minimum
  String sort = 'overall';
  bool ascending = false;

  PlayerFilters();

  PlayerFilters copy() => PlayerFilters()
    ..minValueM = minValueM
    ..maxValueM = maxValueM
    ..minOverall = minOverall
    ..maxOverall = maxOverall
    ..minPotential = minPotential
    ..minAge = minAge
    ..maxAge = maxAge
    ..minHeight = minHeight
    ..maxHeight = maxHeight
    ..foot = foot
    ..minWeakFoot = minWeakFoot
    ..minSkillMoves = minSkillMoves
    ..league = league
    ..nationality = nationality
    ..stats = Map.of(stats)
    ..sort = sort
    ..ascending = ascending;

  /// How many filters are on (sorting is not counted).
  int get activeCount =>
      (minValueM != null || maxValueM != null ? 1 : 0) +
      (minOverall != null || maxOverall != null ? 1 : 0) +
      (minPotential != null ? 1 : 0) +
      (minAge != null || maxAge != null ? 1 : 0) +
      (minHeight != null || maxHeight != null ? 1 : 0) +
      (foot.isNotEmpty ? 1 : 0) +
      (minWeakFoot != null ? 1 : 0) +
      (minSkillMoves != null ? 1 : 0) +
      (league.isNotEmpty ? 1 : 0) +
      (nationality.trim().isNotEmpty ? 1 : 0) +
      stats.length;

  /// Query parameters for the server (only the ones that are set).
  Map<String, String> toQuery() => {
        if (minValueM != null) 'minValue': '${(minValueM! * 1000000).round()}',
        if (maxValueM != null) 'maxValue': '${(maxValueM! * 1000000).round()}',
        if (minOverall != null) 'minOverall': '$minOverall',
        if (maxOverall != null) 'maxOverall': '$maxOverall',
        if (minPotential != null) 'minPotential': '$minPotential',
        if (minAge != null) 'minAge': '$minAge',
        if (maxAge != null) 'maxAge': '$maxAge',
        if (minHeight != null) 'minHeight': '$minHeight',
        if (maxHeight != null) 'maxHeight': '$maxHeight',
        if (foot.isNotEmpty) 'foot': foot,
        if (minWeakFoot != null) 'minWeakFoot': '$minWeakFoot',
        if (minSkillMoves != null) 'minSkillMoves': '$minSkillMoves',
        if (league.isNotEmpty) 'league': league,
        if (nationality.trim().isNotEmpty) 'nationality': nationality.trim(),
        if (stats.isNotEmpty)
          'stats': stats.entries.map((e) => '${e.key}:${e.value}').join(','),
        'sort': sort,
        'dir': ascending ? 'asc' : 'desc',
      };
}

const Map<String, String> _sortOptions = {
  'overall': 'Rating',
  'potential': 'Potential',
  'value': 'Price',
  'wage': 'Wage',
  'age': 'Age',
  'height': 'Height',
};

String sortLabel(String key) =>
    _sortOptions[key] ??
    kStats.firstWhere((s) => s.key == key, orElse: () => const StatDef('', 'Rating', '')).label;

/// Opens the filters sheet. Returns the new filters, or null if dismissed.
Future<PlayerFilters?> showPlayerFilters(BuildContext context, PlayerFilters current) {
  return showModalBottomSheet<PlayerFilters>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.92,
      child: _FiltersSheet(initial: current.copy()),
    ),
  );
}

class _FiltersSheet extends StatefulWidget {
  final PlayerFilters initial;

  const _FiltersSheet({required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late PlayerFilters f = widget.initial;
  late final TextEditingController _minValue =
      TextEditingController(text: _fmt(f.minValueM));
  late final TextEditingController _maxValue =
      TextEditingController(text: _fmt(f.maxValueM));
  late final TextEditingController _nationality =
      TextEditingController(text: f.nationality);
  List<String> _leagues = [];

  @override
  void initState() {
    super.initState();
    Api.playerLeagues().then((l) {
      if (mounted) setState(() => _leagues = l);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _minValue.dispose();
    _maxValue.dispose();
    _nationality.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void _setMax(double m) {
    setState(() {
      f.maxValueM = m;
      _maxValue.text = _fmt(m);
    });
  }

  void _reset() {
    setState(() {
      f = PlayerFilters()..sort = f.sort;
      _minValue.clear();
      _maxValue.clear();
      _nationality.clear();
    });
  }

  void _apply() {
    f.minValueM = _parse(_minValue.text);
    f.maxValueM = _parse(_maxValue.text);
    f.nationality = _nationality.text.trim();
    Navigator.pop(context, f);
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(text, style: displayStyle(size: 22)),
      );

  Widget _rangeRow({
    required String label,
    required double min,
    required double max,
    required int? lo,
    required int? hi,
    required void Function(int?, int?) onChanged,
  }) {
    final values = RangeValues((lo ?? min.toInt()).toDouble(), (hi ?? max.toInt()).toDouble());
    final text = lo == null && hi == null
        ? 'Any'
        : '${lo ?? min.toInt()} – ${hi ?? max.toInt()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textDim)),
            const Spacer(),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          labels: RangeLabels('${values.start.round()}', '${values.end.round()}'),
          onChanged: (v) {
            final a = v.start.round();
            final b = v.end.round();
            setState(() => onChanged(a <= min ? null : a, b >= max ? null : b));
          },
        ),
      ],
    );
  }

  Widget _minChips(String label, int? value, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (var n = 1; n <= 5; n++)
              ChoiceChip(
                label: Text('$n+'),
                selected: value == n,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selectedColor: AppColors.text,
                labelStyle: TextStyle(color: value == n ? AppColors.ink : AppColors.text),
                backgroundColor: AppColors.surfaceHi,
                side: BorderSide.none,
                onSelected: (sel) => setState(() => onChanged(sel ? n : null)),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addStat() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final groups = <String, List<StatDef>>{};
        for (final s in kStats) {
          groups.putIfAbsent(s.group, () => []).add(s);
        }
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final g in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Text(g.key, style: displayStyle(size: 22)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.value)
                        ActionChip(
                          label: Text(s.label),
                          backgroundColor: f.stats.containsKey(s.key)
                              ? AppColors.line
                              : AppColors.surfaceHi,
                          side: BorderSide.none,
                          onPressed: () => Navigator.pop(ctx, s.key),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (key != null) setState(() => f.stats.putIfAbsent(key, () => 75));
  }

  @override
  Widget build(BuildContext context) {
    final sortKeys = [..._sortOptions.keys, ...kStats.map((s) => s.key)];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text('Filters', style: displayStyle(size: 32)),
                _title('Sort by'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sortKeys.contains(f.sort) ? f.sort : 'overall',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          for (final k in sortKeys)
                            DropdownMenuItem(value: k, child: Text(sortLabel(k))),
                        ],
                        onChanged: (v) => setState(() => f.sort = v ?? 'overall'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.arrow_downward, size: 18)),
                        ButtonSegment(value: true, icon: Icon(Icons.arrow_upward, size: 18)),
                      ],
                      selected: {f.ascending},
                      onSelectionChanged: (s) => setState(() => f.ascending = s.first),
                    ),
                  ],
                ),
                _title('Price (millions of €)'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minValue,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'From', suffixText: 'M€', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maxValue,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Up to', suffixText: 'M€', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in [0.5, 1.0, 5.0, 10.0, 25.0, 50.0])
                      ActionChip(
                        label: Text('≤ ${_fmt(m)}M'),
                        backgroundColor: AppColors.surfaceHi,
                        side: BorderSide.none,
                        onPressed: () => _setMax(m),
                      ),
                  ],
                ),
                _title('Player'),
                _rangeRow(
                  label: 'Rating',
                  min: 40,
                  max: 99,
                  lo: f.minOverall,
                  hi: f.maxOverall,
                  onChanged: (a, b) {
                    f.minOverall = a;
                    f.maxOverall = b;
                  },
                ),
                _rangeRow(
                  label: 'Age',
                  min: 15,
                  max: 45,
                  lo: f.minAge,
                  hi: f.maxAge,
                  onChanged: (a, b) {
                    f.minAge = a;
                    f.maxAge = b;
                  },
                ),
                _rangeRow(
                  label: 'Height (cm)',
                  min: 150,
                  max: 205,
                  lo: f.minHeight,
                  hi: f.maxHeight,
                  onChanged: (a, b) {
                    f.minHeight = a;
                    f.maxHeight = b;
                  },
                ),
                Row(
                  children: [
                    const Text('Minimum potential', style: TextStyle(color: AppColors.textDim)),
                    const Spacer(),
                    Text(f.minPotential == null ? 'Any' : '${f.minPotential}+',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: (f.minPotential ?? 40).toDouble(),
                  min: 40,
                  max: 99,
                  divisions: 59,
                  label: '${f.minPotential ?? 40}',
                  onChanged: (v) =>
                      setState(() => f.minPotential = v.round() <= 40 ? null : v.round()),
                ),
                _minChips('Weak foot', f.minWeakFoot, (v) => f.minWeakFoot = v),
                const SizedBox(height: 6),
                _minChips('Skill moves', f.minSkillMoves, (v) => f.minSkillMoves = v),
                const SizedBox(height: 12),
                const Text('Preferred foot', style: TextStyle(color: AppColors.textDim)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '', label: Text('Any')),
                    ButtonSegment(value: 'Left', label: Text('Left')),
                    ButtonSegment(value: 'Right', label: Text('Right')),
                  ],
                  selected: {f.foot},
                  onSelectionChanged: (s) => setState(() => f.foot = s.first),
                ),
                _title('League and country'),
                DropdownButtonFormField<String>(
                  initialValue: _leagues.contains(f.league) ? f.league : '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Real league', isDense: true),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Any league')),
                    for (final l in _leagues) DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: (v) => setState(() => f.league = v ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nationality,
                  decoration: const InputDecoration(labelText: 'Nationality (e.g. spain)', isDense: true),
                ),
                _title('Attributes (minimum)'),
                if (f.stats.isEmpty)
                  const Text(
                    'Add attributes like Pace, Finishing, Stamina, Vision... and only players '
                    'with at least that value will show up.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                  ),
                for (final e in f.stats.entries.toList())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            kStats.firstWhere((s) => s.key == e.key).label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text('${e.value}+', style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => f.stats.remove(e.key)),
                          ),
                        ],
                      ),
                      Slider(
                        value: e.value.toDouble(),
                        min: 1,
                        max: 99,
                        divisions: 98,
                        label: '${e.value}',
                        onChanged: (v) => setState(() => f.stats[e.key] = v.round()),
                      ),
                    ],
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addStat,
                    icon: const Icon(Icons.add),
                    label: const Text('Add attribute'),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(onPressed: _apply, child: const Text('Show players')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
