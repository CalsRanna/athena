import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/page/desktop/home/component/composer_selection_menu.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// composer 里的模型选择菜单：不放数字快捷键与
/// 模型描述，每行只有模型名。
///
/// 在触发行 [anchor]（composer 右下的模型名那一块）上方弹出，右边与它对齐。
/// 当前会话在用的模型行尾打钩；上次在 composer 里选的模型带 `Default` 小标
/// （新会话从它起步）。启用了多个 provider 时按 provider 分组、组名用说明字号；
/// 只有一个 provider 时不显示组名——只有一组时列表就是平铺的。
///
/// 设置页里没有模型选择：新会话的起点就是这里最后一次的选择。
class DesktopModelMenu extends StatelessWidget {
  final Rect anchor;
  final void Function(ModelEntity)? onSelected;

  const DesktopModelMenu({super.key, required this.anchor, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final groups = GetIt.instance<ModelViewModel>().groupedEnabledModels.value;
    final currentId = GetIt.instance<ChatViewModel>().currentModel.value?.id;
    final defaultId = GetIt.instance<SettingViewModel>().chatModel.value?.id;
    final children = <Widget>[
      for (final entry in groups.entries) ...[
        if (groups.length > 1) DesktopContextMenuGroupLabel(text: entry.key),
        for (final model in entry.value)
          DesktopContextMenuTile(
            text: model.name,
            // `Default` 小标跟着名字走，所以并入标题而不是行尾。
            badge: model.id == defaultId
                ? const DesktopMenuDefaultBadge()
                : null,
            selected: model.id == currentId,
            onTap: () => onSelected?.call(model),
          ),
      ],
    ];
    return DesktopComposerSelectionMenu(anchor: anchor, children: children);
  }
}
