import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// composer 里的模型选择菜单：对齐 Claude 的模型选择器，但不放数字快捷键与
/// 模型描述，每行只有模型名。
///
/// 在触发行 [anchor]（composer 右下的模型名那一块）上方弹出，右边与它对齐。
/// 当前会话在用的模型行尾打钩；设置里的默认模型带 `Default` 小标（新会话用它
/// 起步）。启用了多个 provider 时按 provider 分组、组名用说明字号；只有一个
/// provider 时不显示组名——Claude 的列表就是平铺的。
///
/// 设置页里选默认模型仍用下面的 [DesktopModelSelectDialog]。
class DesktopModelSelectMenu extends StatelessWidget {
  final Rect anchor;
  final void Function(ModelEntity)? onSelected;

  const DesktopModelSelectMenu({
    super.key,
    required this.anchor,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groups = GetIt.instance<ModelViewModel>().groupedEnabledModels.value;
    final currentId = GetIt.instance<ChatViewModel>().currentModel.value?.id;
    final defaultId = GetIt.instance<SettingViewModel>().chatModel.value?.id;
    const contentWidth = 264.0;
    final children = <Widget>[
      for (final entry in groups.entries) ...[
        if (groups.length > 1) _GroupLabel(entry.key),
        for (final model in entry.value)
          _ModelTile(
            model: model,
            selected: model.id == currentId,
            isDefault: model.id == defaultId,
            onTap: () => onSelected?.call(model),
          ),
      ],
    ];
    return DesktopContextMenu(
      // 面板自带 4 内边距，左边要比"右对齐"再让出 8
      offset: Offset(anchor.right - contentWidth - 8, anchor.top - 8),
      upward: true,
      width: contentWidth,
      children: [
        DesktopContextMenuList(
          maxHeight: DesktopContextMenuList.maxHeightAbove(anchor),
          children: children,
        ),
      ],
    );
  }
}

/// 分组标题（provider 名）。
class _GroupLabel extends StatelessWidget {
  final String name;
  const _GroupLabel(this.name);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textWeak,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 一行模型：名字（+ `Default` 小标）……行尾打钩表示当前在用。
class _ModelTile extends StatefulWidget {
  final ModelEntity model;
  final bool selected;
  final bool isDefault;
  final void Function()? onTap;

  const _ModelTile({
    required this.model,
    required this.selected,
    required this.isDefault,
    this.onTap,
  });

  @override
  State<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final nameStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final name = Flexible(
      child: Text(
        widget.model.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
    );
    final row = Row(
      children: [
        Expanded(
          child: Row(
            children: [
              name,
              if (widget.isDefault) ...[
                const SizedBox(width: 8),
                const _DefaultBadge(),
              ],
            ],
          ),
        ),
        if (widget.selected) ...[
          const SizedBox(width: 8),
          Icon(
            HugeIcons.strokeRoundedTick02,
            size: 16,
            color: colors.textPrimary,
          ),
        ],
      ],
    );
    final container = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AthenaRadius.row),
        color: hover ? colors.surfaceHover : null,
      ),
      // 与其他菜单条目同一档：12 × 7，高约 32
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      width: width,
      child: row,
    );
    final mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: mouseRegion,
    );
  }

  void handleTap() {
    DesktopContextMenuManager.instance.dismiss();
    widget.onTap?.call();
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }
}

/// Claude 挂在默认模型名后的小标：浅灰底、说明字号、圆角 4。
class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceButtonSecondary,
        borderRadius: BorderRadius.circular(AthenaRadius.xs),
      ),
      child: Text(
        'Default',
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textSecondary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 设置页「默认模型」用的居中对话框（按 provider 分组的完整列表）。
class DesktopModelSelectDialog extends StatelessWidget {
  final void Function(ModelEntity)? onTap;
  const DesktopModelSelectDialog({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final modelViewModel = GetIt.instance<ModelViewModel>();
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(8),
    );

    return Watch((context) {
      var models = modelViewModel.groupedEnabledModels.value;
      var child = _buildData(context, models);
      var container = Container(
        decoration: boxDecoration,
        padding: EdgeInsets.all(8),
        child: child,
      );
      return UnconstrainedBox(child: container);
    });
  }

  Widget _buildData(
    BuildContext context,
    Map<String, List<ModelEntity>> models,
  ) {
    if (models.isEmpty) return const SizedBox();
    List<Widget> children = [];
    for (var entry in models.entries) {
      children.add(_buildItemGroupTitle(context, entry.key));
      children.addAll(entry.value.map(_itemBuilder));
    }
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size(520, 640)),
      child: ListView(shrinkWrap: true, children: children),
    );
  }

  Widget _buildItemGroupTitle(BuildContext context, String title) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: colors.border,
      decoration: TextDecoration.none,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    var thinkIcon = Icon(
      HugeIcons.strokeRoundedBrain02,
      color: colors.iconSecondary,
      size: 18,
    );
    var visualIcon = Icon(
      HugeIcons.strokeRoundedVision,
      color: colors.iconSecondary,
      size: 18,
    );
    var children = [
      Flexible(child: Text(widget.model.name, style: textStyle)),
      if (widget.model.reasoning) thinkIcon,
      if (widget.model.vision) visualIcon,
    ];
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: hover ? colors.surfaceButtonSecondary : null,
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
