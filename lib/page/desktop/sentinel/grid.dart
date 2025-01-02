import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopSentinelGridPage extends ConsumerWidget {
  const DesktopSentinelGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    var state = ref.watch(provider);
    var grid = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return AScaffold(appBar: AAppBar(), body: grid);
  }

  Widget _buildData(List<Sentinel> sentinels) {
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: delegate,
      itemCount: sentinels.length,
      itemBuilder: (context, index) => _SentinelTile(sentinels[index]),
    );
  }
}

class _SentinelTile extends ConsumerWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const nameTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    const descriptionTextStyle = TextStyle(
      color: Color(0xFF616161),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var children = [
      Text(sentinel.name, style: nameTextStyle),
      const SizedBox(height: 4),
      Expanded(child: Text(sentinel.description, style: descriptionTextStyle)),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: container,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) {
    ref.read(sentinelNotifierProvider.notifier).select(sentinel);
    AutoRouter.of(context).maybePop();
  }
}
