import 'package:athena_gui/model/shortcut.dart';
import 'package:athena_gui/page/mobile/home/component/shortcut_page_registry.dart';
import 'package:athena_gui/page/mobile/home/component/shortcut_tile.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/shortcut_view_model.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 首页 Shortcut 卡片行：从 [ShortcutViewModel] 读取，用 [ShortcutPageRegistry]
/// 解析目标页。数据来自 shortcuts 表（绑定 is_preset Sentinel），而非硬编码。
class ShortcutListView extends StatelessWidget {
  final ShortcutViewModel shortcutViewModel;
  final SentinelViewModel sentinelViewModel;
  const ShortcutListView({
    super.key,
    required this.shortcutViewModel,
    required this.sentinelViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var shortcuts = shortcutViewModel.shortcuts.value;
      if (shortcuts.isEmpty) return const SizedBox();
      return ListView.separated(
        itemBuilder: (_, index) {
          final shortcut = shortcuts[index];
          return ShortcutTile(
            icon: ShortcutPageRegistry.iconFor(shortcut.pageTarget) ??
                HugeIcons.strokeRoundedSparkles,
            onTap: () => navigate(context, shortcut),
            shortcut: shortcut,
          );
        },
        itemCount: shortcuts.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
      );
    });
  }

  void navigate(BuildContext context, Shortcut shortcut) {
    // 解析绑定的专属 Sentinel（能力配置）
    final sentinel = sentinelViewModel.sentinels.value
        .where((s) => s.id == shortcut.sentinelId)
        .firstOrNull;

    // 有目标页 → 跳转定制 UI，传入绑定 Sentinel
    final route = ShortcutPageRegistry.routeFor(
      shortcut.pageTarget,
      sentinel: sentinel,
    );
    if (route != null) {
      route.push(context);
      return;
    }

    // 无目标页 → 默认聊天页，绑定专属 Sentinel + JSON 输出场景
    MobileChatRoute(sentinel: sentinel, jsonMode: true).push(context);
  }
}
