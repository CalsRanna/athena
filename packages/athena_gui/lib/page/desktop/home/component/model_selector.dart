import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// composer 里的模型选择菜单：不放数字快捷键与
/// 模型描述，每行只有模型名。
///
/// 在触发行 [anchor]（composer 右下的模型名那一块）上方弹出，右边与它对齐。
/// 当前会话在用的模型行尾打钩；设置里的默认模型带 `Default` 小标（新会话用它
/// 起步）。启用了多个 provider 时按 provider 分组、组名用说明字号；只有一个
/// provider 时不显示组名——只有一组时列表就是平铺的。
///
/// 设置页里选默认模型走另一套控件（`DesktopSettingModelSelector`）。
class DesktopModelMenu extends StatelessWidget {
  final Rect anchor;
  final void Function(ModelEntity)? onSelected;

  const DesktopModelMenu({super.key, required this.anchor, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final groups = GetIt.instance<ModelViewModel>().groupedEnabledModels.value;
    final currentId = GetIt.instance<ChatViewModel>().currentModel.value?.id;
    final defaultId = GetIt.instance<SettingViewModel>().chatModel.value?.id;
    const contentWidth = 264.0;
    final children = <Widget>[
      for (final entry in groups.entries) ...[
        if (groups.length > 1) DesktopContextMenuGroupLabel(text: entry.key),
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
