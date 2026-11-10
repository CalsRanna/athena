import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

/// composer 上下文条里的 Sentinel 选择菜单：与模型选择菜单同一套 UI。
///
/// 在 Sentinel 图标 [anchor] 上方弹出，左边与它对齐；每行只有角色名，当前会话
/// 在用的行尾打钩。列表末尾的「No Sentinel (Direct session)」清掉角色，回到
/// 直接和模型对话。
class DesktopSentinelMenu extends StatelessWidget {
  final Rect anchor;
  final void Function(SentinelEntity)? onSelected;

  const DesktopSentinelMenu({super.key, required this.anchor, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final sentinels = GetIt.instance<SentinelViewModel>().sentinels.value;
    final current = GetIt.instance<ChatViewModel>().currentSentinel.value;
    // Direct chat 与未保存的默认角色都没有 ID，按占位实体区分。
    final direct = identical(current, SentinelViewModel.directChatSentinel);
    final tick = Icon(
      LucideIcons.check,
      size: AthenaIcon.regularSize,
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
                trailing:
                    !direct &&
                        current != null &&
                        (identical(sentinel, current) ||
                            (sentinel.id != null && sentinel.id == current.id))
                    ? tick
                    : null,
                onTap: () => onSelected?.call(sentinel),
              ),
            const DesktopContextMenuSeparator(),
            DesktopContextMenuTile(
              text: SentinelViewModel.directChatOptionLabel,
              selected: direct,
              onTap: () =>
                  onSelected?.call(SentinelViewModel.directChatSentinel),
            ),
          ],
        ),
      ],
    );
  }
}
