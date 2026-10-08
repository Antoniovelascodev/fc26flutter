import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// Asks for one or more PIN fields. Returns the values, or null if cancelled.
/// When there are two fields, they must be equal (create / confirm).
Future<List<String>?> _askPins(
  BuildContext context, {
  required String title,
  required String message,
  required List<String> labels,
  required String confirmLabel,
  bool lastMustMatchPrevious = false,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _PinForm(
      title: title,
      message: message,
      labels: labels,
      confirmLabel: confirmLabel,
      lastMustMatchPrevious: lastMustMatchPrevious,
    ),
  );
}

class _PinForm extends StatefulWidget {
  final String title;
  final String message;
  final List<String> labels;
  final String confirmLabel;
  final bool lastMustMatchPrevious;

  const _PinForm({
    required this.title,
    required this.message,
    required this.labels,
    required this.confirmLabel,
    required this.lastMustMatchPrevious,
  });

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  late final List<TextEditingController> _c =
      List.generate(widget.labels.length, (_) => TextEditingController());
  String? _error;

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = _c.map((c) => c.text.trim()).toList();
    final pinIndex = widget.lastMustMatchPrevious ? values.length - 2 : values.length - 1;
    if (values[pinIndex].length < 4) {
      setState(() => _error = 'The PIN needs at least 4 characters.');
      return;
    }
    if (widget.lastMustMatchPrevious && values.last != values[values.length - 2]) {
      setState(() => _error = 'The two PINs are different.');
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title, style: displayStyle(size: 28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message,
                style: const TextStyle(color: AppColors.textDim, height: 1.4, fontSize: 13)),
            const SizedBox(height: 14),
            for (var i = 0; i < _c.length; i++) ...[
              TextField(
                controller: _c[i],
                obscureText: true,
                autofocus: i == 0,
                decoration: InputDecoration(labelText: widget.labels[i]),
                onSubmitted: (_) {
                  if (i == _c.length - 1) _submit();
                },
              ),
              const SizedBox(height: 10),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Makes sure the team has a PIN and that this device knows it. Creates the PIN
/// the first time, or asks for it if it is not saved here. Returns true when the
/// squads of the team can be created / edited from this device.
Future<bool> ensureTeamPin(BuildContext context, Team team) async {
  if (team.hasPin) {
    if (Api.pinOf(team.id) != null) return true;
    return unlockTeam(context, team);
  }
  final values = await _askPins(
    context,
    title: 'Protect ${team.name}',
    message: 'Choose a PIN for ${team.name}. Only whoever knows it can see or edit '
        'the squads of this team until the squads of a league are revealed. '
        'Do not share it and do not forget it.',
    labels: const ['New PIN', 'Repeat the PIN'],
    confirmLabel: 'Set PIN',
    lastMustMatchPrevious: true,
  );
  if (values == null || !context.mounted) return false;
  try {
    await Api.setTeamPin(team.id, values.first);
    notifyDataChanged();
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, e.toString());
    return false;
  }
}

/// Asks for the PIN of the team and remembers it on this device if it is right.
Future<bool> unlockTeam(BuildContext context, Team team) async {
  final values = await _askPins(
    context,
    title: '${team.name}\'s PIN',
    message: 'Enter the PIN of ${team.name} to see and edit its squads.',
    labels: const ['PIN'],
    confirmLabel: 'Unlock',
  );
  if (values == null || !context.mounted) return false;
  try {
    await Api.unlockTeam(team.id, values.first);
    notifyDataChanged();
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, e.toString());
    return false;
  }
}

Future<void> changeTeamPin(BuildContext context, Team team) async {
  final values = await _askPins(
    context,
    title: 'Change PIN',
    message: 'Change the PIN of ${team.name}.',
    labels: const ['Current PIN', 'New PIN', 'Repeat the new PIN'],
    confirmLabel: 'Change PIN',
    lastMustMatchPrevious: true,
  );
  if (values == null || !context.mounted) return;
  try {
    await Api.setTeamPin(team.id, values[1], currentPin: values[0]);
    if (context.mounted) _toast(context, 'PIN changed');
  } catch (e) {
    if (context.mounted) _toast(context, e.toString());
  }
}
