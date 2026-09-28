import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// composer 左下角的审批模式文字（Claude 的 `Bypass permissions` 那段纯文字）。
///
/// 只负责显示当前档；点击由外层 `_SquishButton` 接管，弹出
/// [DesktopPermissionModeMenu]。
class DesktopPermissionModeLabel extends StatelessWidget {
  const DesktopPermissionModeLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final settingViewModel = GetIt.instance<SettingViewModel>();
    return Watch((context) {
      return Text(
        settingViewModel.approvalMode.value.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
      );
    });
  }
}

/// 审批模式菜单：`Mode` 标题 + 三行（名称 + 一句说明），当前档行尾打钩。
///
/// 对齐 Claude 的 Mode 菜单，但不放数字快捷键——Athena 没有对应的按键。
/// 锚在触发块 [anchor] 上方、左边与它对齐；选中即保存，下一轮 run 生效
/// （与设置 → Agent 里是同一份设置）。
class DesktopPermissionModeMenu extends StatelessWidget {
  final Rect anchor;
  const DesktopPermissionModeMenu({super.key, required this.anchor});

  static void show(BuildContext context, Rect anchor) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopPermissionModeMenu(anchor: anchor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingViewModel = GetIt.instance<SettingViewModel>();
    final current = settingViewModel.approvalMode.value;
    return DesktopContextMenu(
      offset: Offset(anchor.left, anchor.top - 8),
      upward: true,
      width: 296,
      children: [
        const DesktopContextMenuGroupLabel(text: 'Mode'),
        for (final mode in ApprovalMode.values)
          DesktopContextMenuTile(
            text: mode.label,
            description: mode.description,
            selected: mode == current,
            onTap: () => settingViewModel.updateApprovalMode(mode),
          ),
      ],
    );
  }
}
