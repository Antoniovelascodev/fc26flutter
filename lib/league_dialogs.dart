import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

/// Asks for a name and an optional squad budget and creates the league.
/// Returns true when a league was created.
Future<bool> showCreateLeagueDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final budgetController = TextEditingController();
  final result = await showDialog<({String name, int? budget})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('New league', style: displayStyle(size: 28)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'League name'),
              ),
              const SizedBox(height: 14),
              const Text('Squad budget (maximum value of a squad)',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Millions of euros (empty = no limit)',
                  suffixText: 'M€',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [200, 300, 400, 500])
                    ActionChip(
                      label: Text('${m}M'),
                      backgroundColor: AppColors.surfaceHi,
                      side: BorderSide.none,
                      onPressed: () => setLocal(() => budgetController.text = '$m'),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (
              name: nameController.text.trim(),
              budget: int.tryParse(budgetController.text.trim()),
            )),
            child: const Text('Create league'),
          ),
        ],
      ),
    ),
  );
  if (result == null || result.name.isEmpty) return false;
  try {
    await Api.createLeague(result.name, budgetMillions: result.budget);
    notifyDataChanged();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return false;
  }
}
