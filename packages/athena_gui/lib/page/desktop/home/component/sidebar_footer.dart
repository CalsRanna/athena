import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 侧栏底部常驻页脚：一整行可点的应用标识，点击在行的上方弹出菜单。
///
/// 页脚交互：整行 hover 上底色、行尾一枚下拉箭头、
/// 点击弹出带头部（名称 + 版本）的菜单，展开期间行底色保持。
/// Athena 没有账号体系，菜单里只放设置与关于两个真实入口——不摆没有行为的
/// 条目——顶栏因此不再重复放设置按钮。
class DesktopSidebarFooter extends StatefulWidget {
  const DesktopSidebarFooter({super.key});

  @override
  State<DesktopSidebarFooter> createState() => _DesktopSidebarFooterState();
}

class _DesktopSidebarFooterState extends State<DesktopSidebarFooter> {
  /// 菜单展开中。浮层一出来就盖住整窗，行收不到 hover，靠它保持底色。
  bool open = false;
  String version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      decoration: BoxDecoration(
        // 外壳分隔线（页脚上边）：用比 border 轻一档的 borderChrome
        border: Border(top: BorderSide(color: colors.borderChrome)),
      ),
      padding: const EdgeInsets.all(8),
      child: _FooterTile(open: open, onTap: _openMenu),
    );
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      version = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  /// 在 [anchor]（页脚行的全局矩形）上方弹出菜单：面板外沿与行左右对齐、
  /// 底边离行顶 4。
  void _openMenu(Rect anchor) {
    setState(() => open = true);
    final menu = DesktopContextMenu(
      offset: Offset(anchor.left, anchor.top - 4),
      upward: true,
      // 面板自带 4 内边距，条目宽减 8 才能让面板外沿与行同宽
      width: anchor.width - 8,
      children: [
        _FooterMenuHeader(name: 'Athena', version: version),
        const DesktopContextMenuSeparator(),
        DesktopContextMenuTile(
          icon: LucideIcons.settings,
          text: 'Settings',
          onTap: () => const DesktopSettingProviderRoute().push<void>(context),
        ),
        DesktopContextMenuTile(
          icon: LucideIcons.info,
          text: 'About Athena',
          onTap: () => const DesktopSettingAboutRoute().push<void>(context),
        ),
      ],
    );
    DesktopContextMenuManager.instance.show(
      context,
      menu,
      onDismissed: () {
        if (mounted) setState(() => open = false);
      },
    );
  }
}

/// 页脚那一行：应用标识 + 名称 + 下拉箭头。hover 或展开中上 `surfaceHover`。
class _FooterTile extends StatefulWidget {
  final bool open;
  final void Function(Rect anchor) onTap;
  const _FooterTile({required this.open, required this.onTap});

  @override
  State<_FooterTile> createState() => _FooterTileState();
}

class _FooterTileState extends State<_FooterTile> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(AthenaRadius.pill),
      child: Image.asset(
        'asset/image/launcher_icon_ios_512x512.jpg',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        height: 20,
        width: 20,
      ),
    );
    final name = Text(
      'Athena',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
    );
    final chevron = Icon(
      AthenaIcons.dropdown,
      size: AthenaIcon.inlineSize,
      color: colors.iconSecondary,
    );
    final row = Row(
      children: [
        mark,
        const SizedBox(width: 8),
        Expanded(child: name),
        chevron,
      ],
    );
    return AthenaHover(
      onTap: handleTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AnimatedContainer(
        decoration: BoxDecoration(
          // 与列表行一样从目标色的 0 透明度版本插值，避免中途经过黑色
          color: hover || widget.open
              ? colors.surfaceHover
              : colors.surfaceHover.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AthenaRadius.row),
        ),
        duration: AthenaMotion.hover,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: row,
      ),
    );
  }

  void handleTap() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    widget.onTap(box.localToGlobal(Offset.zero) & box.size);
  }
}

/// 菜单头部：应用名 + 版本号。
class _FooterMenuHeader extends StatelessWidget {
  final String name;
  final String version;
  const _FooterMenuHeader({required this.name, required this.version});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final nameStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final versionStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: nameStyle),
          if (version.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(version, style: versionStyle),
          ],
        ],
      ),
    );
  }
}
