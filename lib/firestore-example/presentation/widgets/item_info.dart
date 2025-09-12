import 'package:flutter/material.dart';

class ItemInfo extends StatelessWidget {
  final String label;
  final String value;

  const ItemInfo({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
      ),
    );
  }
}
