import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/widgets.dart';

/// 输入框工具栏的选择菜单，在指示器上方展开，与其右边缘对齐。
class DesktopComposerSelectionMenu extends StatelessWidget {
  final Rect anchor;
  final List<Widget> children;

  const DesktopComposerSelectionMenu({
    super.key,
    required this.anchor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    const contentWidth = 264.0;
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

/// 标出新会话使用的默认选项。
class DesktopMenuDefaultBadge extends StatelessWidget {
  const DesktopMenuDefaultBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
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
