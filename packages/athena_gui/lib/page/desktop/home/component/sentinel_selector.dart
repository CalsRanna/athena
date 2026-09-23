import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// composer 上下文条里的 Sentinel 选择菜单：与模型选择菜单同一套 UI。
///
/// 在 Sentinel chip [anchor] 上方弹出，左边与它对齐；每行只有角色名，当前会话
/// 在用的行尾打钩。没有「No Sentinel」项——清掉角色走 chip 上的清除按钮，
/// 选择器里再放一个"不选"只是重复入口。
class DesktopSentinelSelectMenu extends StatelessWidget {
  final Rect anchor;
  final void Function(SentinelEntity)? onSelected;

  const DesktopSentinelSelectMenu({
    super.key,
    required this.anchor,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final sentinels = GetIt.instance<SentinelViewModel>().sentinels.value;
    final current = GetIt.instance<ChatViewModel>().currentSentinel.value;
    // 「不使用 Sentinel」在 ViewModel 里是 ID = 0 的占位实体，不算选中任何行
    final currentId = current != null && current.id != ChatEntity.noSentinelId
        ? current.id
        : null;
    final tick = Icon(
      LucideIcons.check,
      size: 16,
      color: colors.textPrimary,
    );
    return DesktopContextMenu(
      offset: Offset(anchor.left, anchor.top - 8),
      upward: true,
      width: 264,
      children: [
        DesktopContextMenuList(
          maxHeight: DesktopContextMenuList.maxHeightAbove(anchor),
          children: [
            for (final sentinel in sentinels)
              DesktopContextMenuTile(
                text: sentinel.name,
                trailing: sentinel.id == currentId ? tick : null,
                onTap: () => onSelected?.call(sentinel),
              ),
          ],
        ),
      ],
    );
  }
}
