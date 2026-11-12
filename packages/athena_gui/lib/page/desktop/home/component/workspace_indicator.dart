import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 上下文条上的「本会话工作文件夹」入口，紧跟在 Sentinel 图标之后。
///
/// 与图片加号同一种 ghost 图标按钮（16 字形 + 6 内边距 = 28 方盒）：设置后显示
/// `folder`，未设置显示 `folderX`；当前路径放在 tooltip 里。点击弹出小菜单：
/// 选择文件夹 / 清除文件夹（native 目录选择器选不出「不指定」，清除必须另有
/// 入口）。
///
/// 只影响后续 run：运行中的 run 已在开始时解析并持有自己的基准，改这项不会
/// 让正在跑的一轮中途换目录。
class DesktopWorkspaceIndicator extends StatelessWidget {
  final String? path;
  final void Function()? onTap;
  final void Function()? onClear;

  const DesktopWorkspaceIndicator({
    super.key,
    required this.path,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final set = path != null && path!.isNotEmpty;
    return Tooltip(
      // 只放路径本身/一句话，宽度受限后长路径才换行而不是拉成一整条
      message: set ? path! : 'No working folder',
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 280),
      child: Builder(
        builder: (context) => AthenaGhostButton(
          padding: const EdgeInsets.all(6),
          onTap: () => DesktopContextMenuManager.instance.show(
            context,
            _WorkspaceMenu(
              anchor: DesktopContextMenu.contextMenuAnchorOf(context),
              hasFolder: set,
              onChoose: onTap,
              onClear: onClear,
            ),
          ),
          child: Icon(
            set ? LucideIcons.folder : LucideIcons.folderX,
            color: colors.textPrimary,
            size: AthenaIcon.regularSize,
          ),
        ),
      ),
    );
  }
}

class _WorkspaceMenu extends StatelessWidget {
  final Rect anchor;
  final bool hasFolder;
  final void Function()? onChoose;
  final void Function()? onClear;

  const _WorkspaceMenu({
    required this.anchor,
    required this.hasFolder,
    this.onChoose,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopContextMenu(
      offset: Offset(anchor.left, anchor.top - 8),
      upward: true,
      width: 240,
      children: [
        DesktopContextMenuTile(text: 'Choose folder', onTap: onChoose),
        DesktopContextMenuTile(
          text: 'Clear folder',
          enabled: hasFolder,
          onTap: hasFolder ? onClear : null,
        ),
      ],
    );
  }
}
