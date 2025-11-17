import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopSentinelSelector extends StatelessWidget {
  final void Function(SentinelEntity)? onSelected;
  const DesktopSentinelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedArtificialIntelligence03,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
  }

  void changeModel(SentinelEntity sentinel) {
    AthenaDialog.dismiss();
    onSelected?.call(sentinel);
  }

  void openDialog() {
    AthenaDialog.show(
      _SentinelSelectDialog(onTap: changeModel),
      barrierDismissible: true,
    );
  }
}

class _DesktopSentinelSelectDialogTile extends StatefulWidget {
  final SentinelEntity sentinel;
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

class _SentinelSelectDialog extends StatelessWidget {
  final void Function(SentinelEntity)? onTap;
  const _SentinelSelectDialog({this.onTap});

  @override
  Widget build(BuildContext context) {
    final sentinelViewModel = GetIt.instance<SentinelViewModel>();
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var sentinels = sentinelViewModel.sentinels.value;
      var child = _buildData(sentinels);
      var container = Container(
        decoration: boxDecoration,
        padding: EdgeInsets.all(8),
        child: child,
      );
      return UnconstrainedBox(child: container);
    });
  }

  Widget _buildData(List<SentinelEntity> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    List<Widget> children = sentinels.map(_itemBuilder).toList();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _itemBuilder(SentinelEntity sentinel) {
    return _DesktopSentinelSelectDialogTile(
      sentinel: sentinel,
      onTap: () => onTap?.call(sentinel),
    );
  }
}
