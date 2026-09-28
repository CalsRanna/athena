import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// composer 里的模型选择菜单：不放数字快捷键与
/// 模型描述，每行只有模型名。
///
/// 在触发行 [anchor]（composer 右下的模型名那一块）上方弹出，右边与它对齐。
/// 当前会话在用的模型行尾打钩；设置里的默认模型带 `Default` 小标（新会话用它
/// 起步）。启用了多个 provider 时按 provider 分组、组名用说明字号；只有一个
/// provider 时不显示组名——只有一组时列表就是平铺的。
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
        if (groups.length > 1)
          DesktopContextMenuGroupLabel(text: entry.key),
        for (final model in entry.value)
          DesktopContextMenuTile(
            text: model.name,
            // `Default` 小标跟着名字走，所以并入标题而不是行尾。
            badge: model.id == defaultId ? const _DefaultBadge() : null,
            selected: model.id == currentId,
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

/// 挂在默认模型名后的小标：浅灰底、说明字号、圆角 4。
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
      borderRadius: BorderRadius.circular(AthenaRadius.panel),
      boxShadow: AthenaShadow.modal(colors.shadow),
    );

    return Watch((context) {
      var models = modelViewModel.groupedEnabledModels.value;
      var child = _buildData(context, models);
      var container = Container(
        decoration: boxDecoration,
        foregroundDecoration: Theme.of(context).brightness == Brightness.dark
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AthenaRadius.panel),
                border: Border.all(color: colors.border),
              )
            : null,
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
    // 分组小标题与 DesktopContextMenuGroupLabel 同档：caption + textWeak。
    // 曾经用 colors.border，那是描边色，对画布对比度只有 1.26:1，等于隐形。
    var textStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textWeak,
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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    var thinkIcon = Icon(
      LucideIcons.brainCircuit,
      color: colors.iconSecondary,
      size: 18,
    );
    var visualIcon = Icon(
      LucideIcons.eye,
      color: colors.iconSecondary,
      size: 18,
    );
    var children = [
      Flexible(child: Text(widget.model.name, style: textStyle)),
      if (widget.model.reasoning) thinkIcon,
      if (widget.model.vision) visualIcon,
    ];
    return AthenaHover(
      onTap: widget.onTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AnimatedContainer(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AthenaRadius.row),
          color: hover ? colors.surfaceButtonSecondary : null,
        ),
        duration: AthenaMotion.hover,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(spacing: 8, children: children),
      ),
    );
  }
}
