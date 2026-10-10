import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 设置面板左栏：搜索框 + 分组标题 + 图标行。
///
/// 宽 192（含右侧 1px neutralBorder）、底色 surfacePanel、内边距 12。
/// 行高 36、行距 4、行圆角 8；静止文字 textRowLabel，选中底 neutralSelected
/// 配青瓷 accent 文字。
class AthenaSettingsNav extends StatelessWidget {
  final Widget? search;
  final List<Widget> children;
  const AthenaSettingsNav({super.key, this.search, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final decoration = BoxDecoration(
      color: colors.surfacePanel,
      border: Border(right: BorderSide(color: colors.neutralBorder)),
    );
    final listView = ListView(
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

/// 导航顶部的搜索框。高 36、宽与行同宽、圆角 8、
/// 底色 surfaceMobile、描边 neutralBorder，图标与占位跟随语义色。
class AthenaSettingsSearchField extends StatefulWidget {
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
  State<AthenaSettingsSearchField> createState() =>
      _AthenaSettingsSearchFieldState();
}

class _AthenaSettingsSearchFieldState extends State<AthenaSettingsSearchField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_handleChange);
    widget.controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleChange);
    widget.controller.removeListener(_handleChange);
    focusNode.dispose();
    super.dispose();
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final focused = focusNode.hasFocus;
    final decoration = BoxDecoration(
      color: colors.surfaceMobile,
      border: Border.all(color: focused ? colors.accent : colors.neutralBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.searchRadius),
    );
    final icon = Icon(
      LucideIcons.search,
      color: colors.textWeak,
      size: AthenaSettings.searchIconSize,
    );
    final textStyle = AthenaTextStyle.body.copyWith(color: colors.textPrimary);
    final hintStyle = AthenaTextStyle.body.copyWith(color: colors.textWeak);
    final field = TextField(
      controller: widget.controller,
      cursorColor: colors.textPrimary,
      cursorHeight: 14,
      cursorWidth: 1.5,
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: hintStyle,
      ),
      focusNode: focusNode,
      onChanged: widget.onChanged,
      onTapOutside: (_) => focusNode.unfocus(),
      style: textStyle,
    );
    // 有输入时右端出现清除键
    final clear = widget.controller.text.isEmpty
        ? null
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _clear,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(LucideIcons.x, color: colors.textWeak, size: 12),
            ),
          );
    final children = [
      icon,
      const SizedBox(width: 8),
      Expanded(child: field),
      if (clear != null) const SizedBox(width: 6),
      if (clear != null) clear,
    ];
    return AnimatedContainer(
      duration: AthenaMotion.hover,
      height: AthenaSettings.searchHeight,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: children),
    );
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }
}

/// 导航里的一个分组：小号灰标题 + 若干行。
///
/// 标题字号 12、色 textWeak；标题上方留白 28、下方 13；
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final titleStyle = AthenaTextStyle.caption.copyWith(color: colors.textWeak);
    final label = Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(title, style: titleStyle),
    );
    final header = Padding(
      padding: const EdgeInsets.only(
        top: AthenaSettings.navGroupTopMargin,
        bottom: AthenaSettings.navGroupBottomMargin,
      ),
      child: label,
    );
    final rows = <Widget>[];
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

/// 导航行：图标 + 标签。行高 36、圆角 8、左内缩 12、
/// 图标 16、图标与标签间距 12。
///
/// 选中行只换底色与文字色，**不加粗**：加粗会让整列在切换时跳动。
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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final contentColor = widget.active ? colors.accent : colors.textRowLabel;
    final textStyle = AthenaTextStyle.row.copyWith(
      color: contentColor,
      fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
    );
    final children = [
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
    return AthenaHover(
      onTap: widget.onTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AnimatedContainer(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          // 不能用 Colors.transparent 做插值：它的 RGB 是黑，动画中途会闪深灰。
          color: widget.active
              ? colors.neutralSelected
              : hover
              ? colors.neutralRule
              : colors.neutralRule.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AthenaSettings.navRowRadius),
        ),
        duration: AthenaMotion.hover,
        height: AthenaSettings.navRowHeight,
        padding: const EdgeInsets.only(
          left: AthenaSettings.navRowPadding,
          right: 8,
        ),
        child: Row(children: children),
      ),
    );
  }
}
