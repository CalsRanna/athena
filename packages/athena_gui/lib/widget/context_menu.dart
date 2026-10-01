import 'dart:async';
import 'dart:math' as math;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DesktopContextMenu extends StatelessWidget {
  final Offset offset;
  final double width;
  final List<Widget> children;

  /// 为真时 [offset] 是菜单的**左下角**，菜单从锚点向上展开
  /// （侧栏页脚菜单弹在页脚行上方）；默认 [offset] 是左上角。
  final bool upward;

  const DesktopContextMenu({
    super.key,
    required this.offset,
    this.width = 120,
    this.upward = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final menu = _buildMenu(context);
    // 菜单按 [offset] 定位后再收敛到窗口内（四边各留 8）：设置面板里的
    // 行尾菜单、靠近窗底的选择菜单都可能越界，越界就整体平移回来。
    final positioned = CustomSingleChildLayout(
      delegate: _ContextMenuLayoutDelegate(offset: offset, upward: upward),
      child: menu,
    );
    final children = [const SizedBox.expand(), positioned];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: dismissContextMenu,
      onTap: dismissContextMenu,
      child: Stack(children: children),
    );
  }

  void dismissContextMenu() {
    DesktopContextMenuManager.instance.dismiss();
  }

  Widget _buildMenu(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(AthenaRadius.menu),
      boxShadow: AthenaShadow.overlay(colors.shadow),
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    final container = Container(
      decoration: boxDecoration,
      foregroundDecoration: Theme.of(context).brightness == Brightness.dark
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AthenaRadius.menu),
              border: Border.all(color: colors.border),
            )
          : null,
      padding: const EdgeInsets.all(4),
      child: column,
    );
    // 根 Overlay 不在页面的 Material 下，显式继承应用排版，避免落入调试等宽字体。
    return DesktopContextMenuConfiguration(
      width: width,
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: colors.textPrimary),
        child: container,
      ),
    );
  }
}

/// 把菜单放到锚点处并收敛进窗口。
///
/// [upward] 为真时 [offset] 是菜单的**左下角**（菜单向上展开），否则是左上角；
/// 量到子节点尺寸后再把四边各留 8 的越界量平移回来。
class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset offset;
  final bool upward;
  const _ContextMenuLayoutDelegate({
    required this.offset,
    required this.upward,
  });

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = offset.dx;
    final y = upward ? offset.dy - childSize.height : offset.dy;
    final maxX = math.max(_margin, size.width - childSize.width - _margin);
    final maxY = math.max(_margin, size.height - childSize.height - _margin);
    return Offset(x.clamp(_margin, maxX), y.clamp(_margin, maxY));
  }

  @override
  bool shouldRelayout(_ContextMenuLayoutDelegate oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.upward != upward;
  }
}

class DesktopContextMenuConfiguration extends InheritedWidget {
  final double width;
  const DesktopContextMenuConfiguration({
    super.key,
    required this.width,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant DesktopContextMenuConfiguration oldWidget) {
    return oldWidget.width != width;
  }

  static double widthOf(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<DesktopContextMenuConfiguration>();
    return widget!.width;
  }
}

class DesktopContextMenuTile extends StatefulWidget {
  final bool enabled;
  final void Function()? onTap;
  final String text;

  /// 第二行说明（选择类菜单用）：`caption` / `textSecondary`。
  ///
  /// 给了它就是两行条目（内边距与单行一致，高度由内容撑开）。
  final String? description;

  /// 选中态：行尾补一枚 `check`，并让条目带上「按钮 + 选中」的语义。
  ///
  /// `null`（默认）= 这条不是选择项（右键菜单的 Edit / Delete），什么也不加；
  /// 非 null 才声明语义，所以**未选中的选择项会如实报 `selected: false`**。
  /// 与 [trailing] 同时给出时 [trailing] 负责渲染，本字段只驱动语义。
  final bool? selected;

  /// 紧跟在标题后面的小标（如模型行的 `Default`）。
  ///
  /// 与 [trailing] 不同：它属于标题的一部分，标题省略号在它之前生效，
  /// 不会因为它把标题挤窄到换行之外。
  final Widget? badge;

  /// 危险项（如 Delete）：用深红文字（`dangerText`）。
  final bool danger;

  /// 条目左侧的图标（账号类菜单有，右键菜单没有）。
  final IconData? icon;

  /// 弱化文字但不影响交互（`No model` 这类占位项：灰字，仍可点）。
  /// 与 [enabled] 不同，后者会一并禁用点击与 hover。
  final bool muted;

  /// 条目右侧的附加内容（快捷键提示之类），样式由调用方定。
  final Widget? trailing;

  const DesktopContextMenuTile({
    super.key,
    this.badge,
    this.danger = false,
    this.description,
    this.enabled = true,
    this.icon,
    this.muted = false,
    this.onTap,
    this.selected,
    required this.text,
    this.trailing,
  });

  @override
  State<DesktopContextMenuTile> createState() => _DesktopContextMenuTileState();
}

class _DesktopContextMenuTileState extends State<DesktopContextMenuTile> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    // 浮层不在 Material 之下，文字样式要写全（含 decoration）。
    final textColor = !widget.enabled || widget.muted
        ? colors.textSecondary
        : widget.danger
        ? colors.dangerText
        : colors.textPrimary;
    final textStyle = AthenaTextStyle.row.copyWith(
      color: textColor,
      decoration: TextDecoration.none,
    );
    final width = DesktopContextMenuConfiguration.widthOf(context);
    Widget label = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    // 小标跟在标题后：标题退成 Flexible，长名先省略，不被小标挤掉。
    if (widget.badge != null) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          const SizedBox(width: 8),
          widget.badge!,
        ],
      );
    }
    // 两行条目：标题 `row`、说明 `caption`，间距 2。
    final Widget textBlock = widget.description == null
        ? label
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(height: 2),
              Text(
                widget.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AthenaTextStyle.caption.copyWith(
                  color: colors.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          );
    // 选择项的勾选槽位**常驻**（选中与否都占 16）：否则说明文字会随选中
    // 状态换行。调用方给的 [trailing] 原样贴边，与既有菜单一致。
    final selected = widget.selected;
    Widget? trailing = widget.trailing;
    if (trailing == null && selected != null) {
      trailing = Padding(
        padding: const EdgeInsets.only(left: 8),
        child: SizedBox(
          width: 16,
          child: selected
              ? Icon(
                  LucideIcons.check,
                  size: AthenaIcon.regularSize,
                  color: colors.textPrimary,
                )
              : null,
        ),
      );
    }
    // 没有图标和尾部时保持纯文字，右键菜单不受影响。
    final Widget content = widget.icon == null && trailing == null
        ? textBlock
        : Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: AthenaIcon.regularSize,
                  color: textColor,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: textBlock),
              if (trailing != null) trailing,
            ],
          );
    final tile = AthenaHover(
      enabled: widget.enabled,
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onTap: () {
        DesktopContextMenuManager.instance.dismiss();
        widget.onTap?.call();
      },
      builder: (context, hover) => Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AthenaRadius.row),
          color: hover && widget.enabled ? colors.surfaceHover : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        width: width,
        child: content,
      ),
    );
    // 只有选择类条目才声称自己是按钮 / 选中项；普通右键菜单条目保持
    // 原样，避免给无选中语义的菜单项平白加上 selected: false。
    if (selected == null) return tile;
    return Semantics(button: true, selected: selected, child: tile);
  }
}

class DesktopContextMenuSubItem extends StatefulWidget {
  final String text;
  final void Function()? onTap;

  const DesktopContextMenuSubItem({super.key, required this.text, this.onTap});

  @override
  State<DesktopContextMenuSubItem> createState() =>
      _DesktopContextMenuSubItemState();
}

class _DesktopContextMenuSubItemState extends State<DesktopContextMenuSubItem> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    return AthenaHover(
      cursor: SystemMouseCursors.click,
      onTap: () {
        DesktopContextMenuManager.instance.dismiss();
        widget.onTap?.call();
      },
      builder: (context, hover) => Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AthenaRadius.row),
          color: hover ? colors.surfaceHover : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(widget.text, style: textStyle),
      ),
    );
  }
}

class DesktopContextMenuTileWithSubmenu extends StatefulWidget {
  final bool enabled;
  final String text;
  final List<DesktopContextMenuSubItem> submenuItems;

  const DesktopContextMenuTileWithSubmenu({
    super.key,
    this.enabled = true,
    required this.text,
    required this.submenuItems,
  });

  @override
  State<DesktopContextMenuTileWithSubmenu> createState() =>
      _DesktopContextMenuTileWithSubmenuState();
}

class _DesktopContextMenuTileWithSubmenuState
    extends State<DesktopContextMenuTileWithSubmenu> {
  bool hover = false;
  bool submenuHover = false;
  OverlayEntry? _submenuEntry;
  Timer? _hideTimer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final textColor = widget.enabled
        ? colors.textPrimary
        : colors.textSecondary;
    final textStyle = AthenaTextStyle.row.copyWith(
      color: textColor,
      decoration: TextDecoration.none,
    );
    final boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.row),
      color: hover && widget.enabled ? colors.surfaceHover : null,
    );
    final width = DesktopContextMenuConfiguration.widthOf(context);
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.text, style: textStyle),
        Icon(
          AthenaIcons.forward,
          color: textColor,
          size: AthenaIcon.regularSize,
        ),
      ],
    );
    final container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: width,
      child: row,
    );
    final mouseRegion = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enabled ? handleEnter : null,
      onExit: widget.enabled ? handleExit : null,
      child: container,
    );
    return mouseRegion;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _submenuEntry?.remove();
    _submenuEntry = null;
    super.dispose();
  }

  void handleEnter(PointerEnterEvent event) {
    _hideTimer?.cancel();
    setState(() => hover = true);
    _showSubmenu(event);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
    // 延迟隐藏子菜单，给用户时间移动鼠标到子菜单
    _hideTimer = Timer(AthenaMotion.fast, () {
      if (!submenuHover) {
        _hideSubmenu();
      }
    });
  }

  void _showSubmenu(PointerEnterEvent event) {
    _hideSubmenu();
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final width = DesktopContextMenuConfiguration.widthOf(context);

    final colors = Theme.of(context).extension<AthenaColors>()!;
    final boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(AthenaRadius.menu),
      boxShadow: AthenaShadow.overlay(colors.shadow),
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.submenuItems,
    );
    final container = Container(
      decoration: boxDecoration,
      foregroundDecoration: Theme.of(context).brightness == Brightness.dark
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AthenaRadius.menu),
              border: Border.all(color: colors.border),
            )
          : null,
      padding: const EdgeInsets.all(4),
      width: 168,
      child: column,
    );

    _submenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: offset.dx + width + 8,
            top: offset.dy,
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) {
                  _hideTimer?.cancel();
                  submenuHover = true;
                },
                onExit: (_) {
                  submenuHover = false;
                  _hideSubmenu();
                },
                child: container,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_submenuEntry!);
  }

  void _hideSubmenu() {
    _hideTimer?.cancel();
    _submenuEntry?.remove();
    _submenuEntry = null;
  }
}

class DesktopContextMenuManager {
  OverlayEntry? _entry;
  void Function()? _onDismissed;
  static final DesktopContextMenuManager instance = DesktopContextMenuManager();

  /// [onDismissed] 在菜单以任何方式关掉时回调一次——点外面、选中条目、
  /// 被下一个菜单顶掉——供触发它的控件复位"展开中"状态。
  ///
  /// 菜单一律插进**根 Overlay**：菜单的坐标是全局坐标（`globalPosition` /
  /// [contextMenuAnchorOf]），而最近的 Overlay 可能属于嵌套 Navigator
  /// （设置面板的内容区就是一个），它的原点不在窗口左上角，插进去会整体偏移。
  void show(
    BuildContext context,
    Widget contextMenu, {
    void Function()? onDismissed,
  }) {
    dismiss();
    _entry = OverlayEntry(builder: (_) => contextMenu);
    _onDismissed = onDismissed;
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void dismiss() {
    _entry?.remove();
    _entry = null;
    final callback = _onDismissed;
    _onDismissed = null;
    callback?.call();
  }
}

/// [context] 对应控件的全局矩形，供弹出菜单锚定（模型名、Sentinel chip 等）。
Rect contextMenuAnchorOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// 菜单里可滚动的条目列表：超过 [maxHeight] 时在面板内滚，宽度取菜单配置。
///
/// 模型 / Sentinel 这类选择菜单用它，条目多时不至于撑满整窗。
class DesktopContextMenuList extends StatelessWidget {
  final double maxHeight;
  final List<Widget> children;
  const DesktopContextMenuList({
    super.key,
    required this.maxHeight,
    required this.children,
  });

  /// 弹在 [anchor] 上方的选择菜单能用的最大高度：选择器就是一小段
  /// 列表，这里封顶 320（约十行）；同时不超过锚点上方、离窗顶留 12 的空间。
  static double maxHeightAbove(Rect anchor) =>
      math.min(320.0, math.max(anchor.top - 20, 120.0));

  @override
  Widget build(BuildContext context) {
    final width = DesktopContextMenuConfiguration.widthOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SizedBox(
        width: width,
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: children,
        ),
      ),
    );
  }
}

/// 菜单里的分组小标题（provider 名、`Mode` 之类）：说明字号、`textWeak`。
class DesktopContextMenuGroupLabel extends StatelessWidget {
  final String text;
  const DesktopContextMenuGroupLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // 分组说明使用辅助档，清除从触发控件带入的文字装饰。
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textWeak,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 菜单分组之间的 1px 细线（Archive / Delete 之前有一条）。
class DesktopContextMenuSeparator extends StatelessWidget {
  const DesktopContextMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    return Container(
      width: width,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colors.border,
    );
  }
}
