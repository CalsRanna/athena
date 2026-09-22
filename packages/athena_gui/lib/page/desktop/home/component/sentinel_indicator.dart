import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 上下文条上的「本会话角色」入口。
///
/// 与工作文件夹 chip 同一种 chip（`filled: false`——带的底色已是浅灰，chip 再
/// 画一层同色底就成了看不见的胶囊）。点击弹出角色菜单（锚在 chip 上方，
/// 所以 [onTap] 回传 chip 的全局矩形）。可以清除：清掉就是「不使用 Sentinel」
/// （`ChatEntity.noSentinelId`，即直接和模型对话），此时标签显示 `No Sentinel`
/// 且不再出现清除按钮。完整语义与 `SentinelViewModel.directChatSentinel` 一致。
/// 菜单里没有「No Sentinel」项，清除只走这里的叉。
class DesktopSentinelIndicator extends StatelessWidget {
  final void Function(Rect anchor)? onTap;

  /// 清除本会话的角色，回到「不选择任何 Sentinel」。为 null 时不显示清除按钮。
  final void Function()? onClear;

  const DesktopSentinelIndicator({super.key, this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final chatViewModel = GetIt.instance<ChatViewModel>();
    return Watch((context) {
      final sentinel = chatViewModel.currentSentinel.value;
      // ViewModel 会把「不使用 Sentinel」的会话解析成 directChatSentinel
      // （保留 ID = 0 的假实体，不写 sentinels 表），所以按 ID 判有没有角色。
      final hasSentinel =
          sentinel != null && sentinel.id != ChatEntity.noSentinelId;
      final label = hasSentinel ? sentinel.name : 'No Sentinel';
      // Builder 拿到 chip 自己的矩形回传，菜单左边要与它对齐
      return Builder(
        builder: (context) => AthenaContextChip(
          label: label,
          leading: const Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
          onTap: onTap == null
              ? null
              : () => onTap!(contextMenuAnchorOf(context)),
          filled: false,
          // 内层 onTap 在命中测试里先于 chip 的 onTap 生效
          trailing: hasSentinel && onClear != null
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const Icon(HugeIcons.strokeRoundedCancel01, size: 12),
                )
              : null,
        ),
      );
    });
  }
}
