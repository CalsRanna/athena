import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:flutter/material.dart';

/// composer 左下角的审批模式文字（如 `Bypass permissions`）。
///
/// 只负责显示当前档；点击由外层 `_SquishButton` 接管，弹出
/// [DesktopPermissionModeMenu]。
///
/// 档位是**会话级**的，所以值由页面传入（`ChatViewModel.currentApprovalMode`）
/// 而不是自己从 ViewModel 取：草稿态与已选会话读的是同一个信号，widget
/// 不需要知道当前处于哪种状态。
class DesktopPermissionModeLabel extends StatelessWidget {
  final ApprovalMode current;
  const DesktopPermissionModeLabel({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Text(
      current.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
    );
  }
}

/// 审批模式菜单：`Mode` 标题 + 三行（名称 + 一句说明），当前档行尾打钩。
///
/// 不放数字快捷键——Athena 没有对应的按键。
/// 锚在触发块 [anchor] 上方、左边与它对齐；选中即保存到当前会话
/// （或草稿），下一轮 run 生效。
class DesktopPermissionModeMenu extends StatelessWidget {
  final Rect anchor;
  final ApprovalMode current;
  final void Function(ApprovalMode)? onSelected;

  const DesktopPermissionModeMenu({
    super.key,
    required this.anchor,
    required this.current,
    this.onSelected,
  });

  static void show(
    BuildContext context,
    Rect anchor, {
    required ApprovalMode current,
    void Function(ApprovalMode)? onSelected,
  }) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopPermissionModeMenu(
        anchor: anchor,
        current: current,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            onTap: () => onSelected?.call(mode),
          ),
      ],
    );
  }
}
