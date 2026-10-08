import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<League> _leagues = [];
  bool _loading = true;
  Object? _error;

  int? _leagueId;
  Future<List<MatchItem>>? _matches;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
    dataVersion.addListener(_loadLeagues);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_loadLeagues);
    super.dispose();
  }

  Future<void> _loadLeagues() async {
    try {
      final leagues = await Api.leagues();
      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _error = null;
        _loading = false;
        if (!leagues.any((l) => l.id == _leagueId)) {
          _leagueId = leagues.isNotEmpty ? leagues.last.id : null;
        }
        _matches = _leagueId == null ? null : Api.matchesByLeague(_leagueId!);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _selectLeague(int id) {
    setState(() {
      _leagueId = id;
      _matches = Api.matchesByLeague(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() => _loading = true);
          _loadLeagues();
        },
      );
    }
    if (_leagues.isEmpty) {
      return const EmptyView(
        title: 'No leagues yet',
        message: 'Create a league in New match and its results will show up here.',
      );
    }

    return Column(
      children: [
        LeagueChips(
          leagues: _leagues,
          selectedId: _leagueId,
          onSelected: _selectLeague,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: FutureBuilder<List<MatchItem>>(
            future: _matches,
            builder: (context, snap) {
              if (_matches == null) return const SizedBox.shrink();
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorView(
                  error: snap.error!,
                  onRetry: () => _selectLeague(_leagueId!),
                );
              }
              final matches = snap.data!;
              if (matches.isEmpty) {
                return const EmptyView(
                  title: 'Nothing played here yet',
                  message: 'Matches saved in this league will be listed here, newest first.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: matches.length,
                itemBuilder: (context, i) => MatchStrip(match: matches[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
