import 'package:athena/entity/model_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/widget/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DesktopModelSelectDialog extends StatelessWidget {
  final void Function(ModelEntity)? onTap;
  const DesktopModelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final modelViewModel = GetIt.instance<ModelViewModel>();
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FF282F32,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var models = modelViewModel.groupedEnabledModels.value;
      var child = _buildData(models);
      var container = Container(
        decoration: boxDecoration,
        padding: EdgeInsets.all(8),
        child: child,
      );
      return UnconstrainedBox(child: container);
    });
  }

  Widget _buildData(Map<String, List<ModelEntity>> models) {
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

  Widget _itemBuilder(ModelEntity model) {
    return _DesktopModelSelectDialogTile(
      model: model,
      onTap: () => onTap?.call(model),
    );
  }
}

class DesktopModelSelector extends StatelessWidget {
  final void Function(ModelEntity)? onSelected;
  const DesktopModelSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedAiBrain01,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
  }

  void changeModel(ModelEntity model) {
    AthenaDialog.dismiss();
    onSelected?.call(model);
  }

  Future<void> openDialog() async {
    final modelViewModel = GetIt.instance<ModelViewModel>();
    var hasModel = modelViewModel.enabledModels.value.isNotEmpty;
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
  final ModelEntity model;
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
      if (widget.model.reasoning) thinkIcon,
      if (widget.model.vision) visualIcon,
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
