import 'package:flutter/material.dart';

class SettingTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget child;

  const SettingTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final leading = SizedBox(width: 200, child: Text(label));
    final expanded = Expanded(child: child);
    var children = [
      Row(children: [leading, expanded]),
      _buildSubtitle(context),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: column,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    if (subtitle == null) return const SizedBox();
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.onSurface.withValues(alpha: 0.4);
    return Text(subtitle!, style: TextStyle(color: color, fontSize: 10));
  }
}
