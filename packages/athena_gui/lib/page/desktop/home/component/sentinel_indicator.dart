import 'package:athena_gui/extension/athena_theme_context.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 上下文条上的「本会话角色」入口。
///
/// 与图片加号同一种 ghost 图标按钮（16 字形 + 6 内边距 = 28 方盒）：有 Sentinel
/// 时显示 `userRound`，直接用模型对话（`ChatEntity.noSentinelId`）时显示
/// `userRoundX`；角色名收在 tooltip 里。点击弹出角色菜单（锚在图标上方，
/// 所以 [onTap] 回传图标的全局矩形）；清除也走菜单末尾的
/// 「No Sentinel (Direct session)」一行。
class DesktopSentinelIndicator extends StatelessWidget {
  final void Function(Rect anchor)? onTap;

  const DesktopSentinelIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return SignalBuilder(
      builder: (context) {
        final sentinel = chatViewModel.currentSentinel.value;
        // ViewModel 会把「不使用 Sentinel」的会话解析成 directChatSentinel
        // 默认角色尚未落盘时 ID 也为空，只把明确的直接对话占位视为无角色。
        final hasSentinel =
            sentinel != null &&
            !identical(sentinel, SentinelViewModel.directChatSentinel);
        // 标签收进 tooltip：当前角色名 / 「No Sentinel」。
        return Tooltip(
          message: hasSentinel ? sentinel.name : 'No Sentinel',
          preferBelow: false,
          constraints: const BoxConstraints(maxWidth: 280),
          // Builder 拿到按钮自己的矩形回传，菜单左边要与它对齐
          child: Builder(
            builder: (context) => AthenaGhostButton(
              padding: const EdgeInsets.all(6),
              onTap: onTap == null
                  ? null
                  : () =>
                        onTap!(DesktopContextMenu.contextMenuAnchorOf(context)),
              child: Icon(
                hasSentinel ? LucideIcons.userRound : LucideIcons.userRoundX,
                color: colors.textPrimary,
                size: AthenaIcon.regularSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
