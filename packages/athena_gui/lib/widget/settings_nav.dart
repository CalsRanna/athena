import 'package:athena_gui/theme/athena_settings.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 设置面板左栏：搜索框 + 分组标题 + 图标行。
///
/// 实测：宽 192（含右侧 1px 分界 `#E4E4E3`）、底色 `#FCFCFB`、内边距 12。
/// 行高 32、行距 2、行圆角 8；静止文字 `#52514F`，选中底 `#E3E3E2` +
/// 近黑文字。
class AthenaSettingsNav extends StatelessWidget {
  final Widget? search;
  final List<Widget> children;
  const AthenaSettingsNav({super.key, this.search, required this.children});

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.nav,
      border: Border(right: BorderSide(color: settings.navDivider)),
    );
    var listView = ListView(
      padding: const EdgeInsets.all(AthenaSettings.navPadding),
      children: [if (search != null) search!, ...children],
    );
    return Container(
      width: AthenaSettings.navWidth,
      decoration: decoration,
      child: listView,
    );
  }
}

/// 导航顶部的搜索框。实测高 32、宽与行同宽、圆角 8、
/// 底色 `#FEFEFD`、描边 `#E6E6E5`、图标与占位都是 `#898781`。
class AthenaSettingsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  const AthenaSettingsSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.placeholder = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.searchFill,
      border: Border.all(color: settings.searchBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.searchRadius),
    );
    var icon = Icon(
      HugeIcons.strokeRoundedSearch01,
      color: settings.navMuted,
      size: AthenaSettings.searchIconSize,
    );
    var textStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.searchFontSize,
      height: 1.3,
    );
    var hintStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.searchFontSize,
      height: 1.3,
    );
    var field = TextField(
      controller: controller,
      cursorColor: settings.navSelectedText,
      cursorHeight: 14,
      cursorWidth: 1.5,
      decoration: InputDecoration.collapsed(
        hintText: placeholder,
        hintStyle: hintStyle,
      ),
      onChanged: onChanged,
      style: textStyle,
    );
    var children = [icon, const SizedBox(width: 8), Expanded(child: field)];
    return Container(
      height: AthenaSettings.searchHeight,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: children),
    );
  }
}

/// 导航里的一个分组：小号灰标题 + 若干行。
///
/// 实测标题字号 12、色 `#898781`；标题上方留白 28、下方 13;
/// 标题左缩进 10（与行的图标列对齐）。
class AthenaSettingsNavGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const AthenaSettingsNavGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var titleStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.navGroupFontSize,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
    var label = Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(title, style: titleStyle),
    );
    var header = Padding(
      padding: const EdgeInsets.only(
        top: AthenaSettings.navGroupTopMargin,
        bottom: AthenaSettings.navGroupBottomMargin,
      ),
      child: label,
    );
    var rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const SizedBox(height: AthenaSettings.navRowGap));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, ...rows],
    );
  }
}

/// 导航行：图标 + 标签。实测行高 32、圆角 8、左内缩 12、
/// 图标 16、图标与标签间距 12。
class AthenaSettingsNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final Widget? trailing;
  const AthenaSettingsNavItem({
    super.key,
    required this.label,
    required this.icon,
    this.active = false,
    this.onTap,
    this.trailing,
  });

  @override
  State<AthenaSettingsNavItem> createState() => _AthenaSettingsNavItemState();
}

class _AthenaSettingsNavItemState extends State<AthenaSettingsNavItem> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var contentColor = widget.active
        ? settings.navSelectedText
        : settings.navText;
    // 不能用 Colors.transparent 做插值：它的 RGB 是黑，动画中途会闪深灰。
    var background = widget.active
        ? settings.navSelected
        : hover
        ? settings.rule
        : settings.rule.withValues(alpha: 0);
    var textStyle = TextStyle(
      color: contentColor,
      fontSize: AthenaSettings.navFontSize,
      fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
      height: 1.3,
    );
    var children = [
      Icon(widget.icon, color: contentColor, size: AthenaSettings.navIconSize),
      const SizedBox(width: AthenaSettings.navIconGap),
      Expanded(
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
      if (widget.trailing != null) widget.trailing!,
    ];
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AthenaSettings.navRowRadius),
      ),
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.navRowHeight,
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(children: children),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: container,
      ),
    );
  }
}
