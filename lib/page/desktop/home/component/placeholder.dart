import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSentinelPlaceholder extends ConsumerWidget {
  const DesktopSentinelPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentinel = ref.watch(sentinelNotifierProvider).valueOrNull;
    if (sentinel == null) return const SizedBox();
    var nameTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
    var descriptionTextStyle = TextStyle(
      color: Color(0xFFC2C2C2),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var children = [
      Text(sentinel.name, style: nameTextStyle),
      const SizedBox(height: 12),
      _TagWrap(sentinel: sentinel),
      const SizedBox(height: 12),
      Text(sentinel.description, style: descriptionTextStyle),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

class _TagWrap extends StatelessWidget {
  final Sentinel sentinel;

  const _TagWrap({required this.sentinel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: sentinel.tags.map(_buildTile).toList(),
    );
  }

  Widget _buildTile(String tag) {
    var textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    var innerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      color: Color(0xFF161616),
    );
    var innerContainer = Container(
      decoration: innerBoxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
      child: Text(tag, style: textStyle),
    );
    var colors = [
      Color(0xFFEAEAEA).withValues(alpha: 0.17),
      Colors.white.withValues(alpha: 0),
    ];
    var linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    var outerBoxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: linearGradient,
    );
    return Container(
      decoration: outerBoxDecoration,
      padding: EdgeInsets.all(1),
      child: innerContainer,
    );
  }
}
