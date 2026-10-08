import 'package:flutter/material.dart';

import 'api.dart';
import 'widgets.dart';

/// Loads data, shows a spinner / error with retry, and reloads whenever the app
/// data changes (a match was saved, a squad edited...).
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// When true, the spinner is small and inline (for blocks inside a page).
  final bool compact;

  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.compact = false,
  });

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  @override
  void initState() {
    super.initState();
    dataVersion.addListener(_reload);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.all(widget.compact ? 20 : 48),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        if (snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: _reload);
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }
}
