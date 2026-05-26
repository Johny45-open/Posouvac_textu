import 'package:flutter/material.dart';

class AppProgressIndicator extends StatelessWidget {
  final double? value;
  final String label;

  const AppProgressIndicator({
    super.key,
    this.value,
    this.label = "Načítám...",
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            semanticsLabel: label,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
