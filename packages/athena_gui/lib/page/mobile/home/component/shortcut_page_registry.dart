import 'package:athena_gui/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 一个 [Shortcut] 的目标页定义。
class ShortcutPageDef {
  final IconData icon;
  final PageRouteInfo Function() routeBuilder;

  const ShortcutPageDef({
    required this.icon,
    required this.routeBuilder,
  });
}

/// Shortcut 目标页注册表：把 `page_target` 字符串映射到路由 + 图标。
///
/// 替代旧 `shortcut_list_view.dart` 里的硬编码 `switch`。这是纯查找表，
/// 不是插件机制——当前内置 5 个目标页，后续可在此扩展。
class ShortcutPageRegistry {
  ShortcutPageRegistry._();

  static final Map<String, ShortcutPageDef> _pages = {
    'translation': ShortcutPageDef(
      icon: HugeIcons.strokeRoundedTranslate,
      routeBuilder: MobileTranslationRoute.new,
    ),
    'summary': ShortcutPageDef(
      icon: HugeIcons.strokeRoundedAiBrowser,
      routeBuilder: MobileSummaryRoute.new,
    ),
    'trpg': ShortcutPageDef(
      icon: HugeIcons.strokeRoundedGame,
      routeBuilder: MobileTRPGRoute.new,
    ),
  };

  /// 返回目标页路由；[pageTarget] 为空（默认聊天页）或未注册时返回 null。
  static PageRouteInfo? routeFor(String? pageTarget) {
    final def = pageTarget == null ? null : _pages[pageTarget];
    return def?.routeBuilder();
  }

  /// 返回目标页图标；未注册或为空时返回 null（由调用方提供兜底图标）。
  static IconData? iconFor(String? pageTarget) {
    final def = pageTarget == null ? null : _pages[pageTarget];
    return def?.icon;
  }

  static bool has(String pageTarget) => _pages.containsKey(pageTarget);
}
