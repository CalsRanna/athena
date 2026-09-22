import 'package:athena_core/entity/approval_mode.dart';
import 'package:athena_gui/component/approval_mode_label.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
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
        const _MenuHeader('Mode'),
        for (final mode in ApprovalMode.values)
          _ModeTile(
            mode: mode,
            selected: mode == current,
            onTap: () => settingViewModel.updateApprovalMode(mode),
          ),
      ],
    );
  }
}

/// 菜单顶部的小标题。
class _MenuHeader extends StatelessWidget {
  final String text;
  const _MenuHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textWeak,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 一档：名称 + 说明两行，选中行尾打钩。
class _ModeTile extends StatefulWidget {
  final ApprovalMode mode;
  final bool selected;
  final void Function()? onTap;

  const _ModeTile({required this.mode, required this.selected, this.onTap});

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final titleStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final descriptionStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.mode.label, maxLines: 1, style: titleStyle),
        const SizedBox(height: 2),
        Text(
          widget.mode.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: descriptionStyle,
        ),
      ],
    );
    final row = Row(
      children: [
        Expanded(child: text),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
