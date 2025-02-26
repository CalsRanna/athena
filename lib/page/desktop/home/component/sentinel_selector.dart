import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/widget/card.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopSentinelSelector extends StatelessWidget {
  final void Function(Sentinel)? onSelected;
  const DesktopSentinelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedArtificialIntelligence03,
      color: ColorUtil.FF616161,
      size: 24,
    );
    return GestureDetector(
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
  }

  void changeModel(Sentinel sentinel) {
    ADialog.dismiss();
    onSelected?.call(sentinel);
  }

  void openDialog() {
    ADialog.show(
      _SentinelSelectDialog(onTap: changeModel),
      barrierDismissible: true,
    );
  }
}

class _SentinelSelectDialog extends ConsumerWidget {
  final void Function(Sentinel)? onTap;
  const _SentinelSelectDialog({this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sentinelsNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    return UnconstrainedBox(
      child: ACard(borderRadius: BorderRadius.circular(24), child: child),
    );
  }

  Widget _buildData(List<Sentinel> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    List<Widget> children = sentinels.map(_itemBuilder).toList();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(500, 600)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _itemBuilder(Sentinel sentinel) {
    return _DesktopSentinelSelectDialogTile(
      sentinel: sentinel,
      onTap: () => onTap?.call(sentinel),
    );
  }
}

class _DesktopSentinelSelectDialogTile extends StatefulWidget {
  final Sentinel sentinel;
  final void Function()? onTap;
  const _DesktopSentinelSelectDialogTile({required this.sentinel, this.onTap});

  @override
  State<_DesktopSentinelSelectDialogTile> createState() =>
      _DesktopSentinelSelectDialogTileState();
}

class _DesktopSentinelSelectDialogTileState
    extends State<_DesktopSentinelSelectDialogTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? ColorUtil.FF616161 : null,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(widget.sentinel.name, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}
