import 'package:athena/provider/model.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopModelSelectDialog extends ConsumerWidget {
  final void Function(Model)? onTap;
  const DesktopModelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupedEnabledModelsNotifierProvider);
    var child = switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );
    var container = Container(
      decoration: boxDecoration,
      padding: EdgeInsets.all(8),
      child: child,
    );
    return UnconstrainedBox(child: container);
  }

  Widget _buildData(Map<String, List<Model>> models) {
    if (models.isEmpty) return const SizedBox();
    List<Widget> children = [];
    for (var entry in models.entries) {
      children.add(_buildItemGroupTitle(entry.key));
      children.addAll(entry.value.map(_itemBuilder));
    }
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _buildItemGroupTitle(String title) {
    var textStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(title, style: textStyle),
    );
  }

  Widget _itemBuilder(Model model) {
    return _DesktopModelSelectDialogTile(
      model: model,
      onTap: () => onTap?.call(model),
    );
  }
}

class DesktopModelSelector extends ConsumerWidget {
  final void Function(Model)? onSelected;
  const DesktopModelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedAiBrain01,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      onTap: () => openDialog(ref),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
  }

  void changeModel(Model model) {
    AthenaDialog.dismiss();
    onSelected?.call(model);
  }

  Future<void> openDialog(WidgetRef ref) async {
    var hasModel = await ModelViewModel(ref).hasModel();
    if (hasModel) {
      AthenaDialog.show(
        DesktopModelSelectDialog(onTap: changeModel),
        barrierDismissible: true,
      );
    } else {
      AthenaDialog.message('Your should enable a provider first');
    }
  }
}

class _DesktopModelSelectDialogTile extends StatefulWidget {
  final Model model;
  final void Function()? onTap;
  const _DesktopModelSelectDialogTile({required this.model, this.onTap});

  @override
  State<_DesktopModelSelectDialogTile> createState() =>
      _DesktopModelSelectDialogTileState();
}

class _DesktopModelSelectDialogTileState
    extends State<_DesktopModelSelectDialogTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      decoration: TextDecoration.none,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: ColorUtil.FFE0E0E0,
      size: 18,
    );
    var children = [
      Flexible(child: Text(widget.model.name, style: textStyle)),
      if (widget.model.supportReasoning) thinkIcon,
      if (widget.model.supportVisual) visualIcon,
    ];
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? ColorUtil.FF616161 : null,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(spacing: 8, children: children),
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
