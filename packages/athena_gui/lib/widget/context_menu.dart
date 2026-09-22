import 'dart:async';
import 'dart:math' as math;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    var menu = _buildMenu(context);
    // 菜单按 [offset] 定位后再收敛到窗口内（四边各留 8）：设置面板里的
    // 行尾菜单、靠近窗底的选择菜单都可能越界，越界就整体平移回来。
    var positioned = CustomSingleChildLayout(
      delegate: _ContextMenuLayoutDelegate(offset: offset, upward: upward),
      child: menu,
    );
    var children = [const SizedBox.expand(), positioned];
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
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(AthenaRadius.menu),
      boxShadow: AthenaShadow.overlay(colors.shadow),
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(4),
      child: column,
    );
    return DesktopContextMenuConfiguration(width: width, child: container);
  }
}

/// 把菜单放到锚点处并收敛进窗口。
///
/// [upward] 为真时 [offset] 是菜单的**左下角**（菜单向上展开），否则是左上角；
/// 量到子节点尺寸后再把四边各留 8 的越界量平移回来。
class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset offset;
  final bool upward;
  const _ContextMenuLayoutDelegate({required this.offset, required this.upward});

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = offset.dx;
    var y = upward ? offset.dy - childSize.height : offset.dy;
    var maxX = math.max(_margin, size.width - childSize.width - _margin);
    var maxY = math.max(_margin, size.height - childSize.height - _margin);
    return Offset(x.clamp(_margin, maxX), y.clamp(_margin, maxY));
  }

  @override
  bool shouldRelayout(_ContextMenuLayoutDelegate oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.upward != upward;
  }
}

/// 列表条目通用的「编辑 / 删除」右键菜单。
///
/// [multiSelect] 为真时禁用多选下无意义的「编辑」；[leading] 用于插入
/// 条目特有的额外动作（如模型条目的 Connect）。
class DesktopEditDeleteContextMenu extends StatelessWidget {
  final Offset offset;
  final bool multiSelect;
  final void Function()? onEdited;
  final void Function()? onDestroyed;
  final List<Widget> leading;

  const DesktopEditDeleteContextMenu({
    super.key,
    required this.offset,
    this.multiSelect = false,
    this.onEdited,
    this.onDestroyed,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      ...leading,
      DesktopContextMenuTile(
        text: 'Edit',
        onTap: onEdited,
        enabled: !multiSelect,
      ),
      DesktopContextMenuTile(text: 'Delete', onTap: onDestroyed),
    ];
    return DesktopContextMenu(offset: offset, children: children);
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
    var widget = context
        .dependOnInheritedWidgetOfExactType<DesktopContextMenuConfiguration>();
    return widget!.width;
  }
}

class DesktopContextMenuTile extends StatefulWidget {
  final bool enabled;
  final void Function()? onTap;
  final String text;

  /// 危险项（如 Delete）：Claude 用深红文字。
  final bool danger;

  /// 条目左侧的图标（Claude 的账号菜单有，右键菜单没有）。
  final IconData? icon;

  /// 条目右侧的附加内容（快捷键提示之类），样式由调用方定。
  final Widget? trailing;

  const DesktopContextMenuTile({
    super.key,
    this.danger = false,
    this.enabled = true,
    this.icon,
    this.onTap,
    required this.text,
    this.trailing,
  });

  @override
  State<DesktopContextMenuTile> createState() => _DesktopContextMenuTileState();
}

class _DesktopContextMenuTileState extends State<DesktopContextMenuTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textColor = !widget.enabled
        ? colors.textSecondary
        : widget.danger
        ? colors.dangerText
        : colors.textPrimary;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: textColor,
      decoration: TextDecoration.none,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.row),
      color: hover && widget.enabled ? colors.surfaceHover : null,
    );
    var width = DesktopContextMenuConfiguration.widthOf(context);
    var label = Text(
      widget.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
    // 没有图标和尾部时保持纯文字，右键菜单不受影响。
    Widget content = widget.icon == null && widget.trailing == null
        ? label
        : Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: textColor),
                const SizedBox(width: 10),
              ],
              Expanded(child: label),
              if (widget.trailing != null) widget.trailing!,
            ],
          );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      // Claude 实测：菜单项高约 32 逻辑
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      width: width,
      child: content,
    );
    var mouseRegion = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? handleTap : null,
      child: mouseRegion,
    );
  }

  void handleTap() {
    DesktopContextMenuManager.instance.dismiss();
    widget.onTap?.call();
  }

  void handleEnter(PointerEnterEvent _) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent _) {
    setState(() {
      hover = false;
    });
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
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      decoration: TextDecoration.none,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.row),
      color: hover ? colors.surfaceHover : null,
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(widget.text, style: textStyle),
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        DesktopContextMenuManager.instance.dismiss();
        widget.onTap?.call();
      },
      child: mouseRegion,
    );
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
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
    var textColor = widget.enabled ? colors.textPrimary : colors.textSecondary;
    var textStyle = AthenaTextStyle.row.copyWith(
      color: textColor,
      decoration: TextDecoration.none,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(AthenaRadius.row),
      color: hover && widget.enabled ? colors.surfaceHover : null,
    );
    var width = DesktopContextMenuConfiguration.widthOf(context);
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.text, style: textStyle),
        Icon(Icons.chevron_right, color: textColor, size: 16),
      ],
    );
    var container = Container(
      alignment: Alignment.centerLeft,
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: width,
      child: row,
    );
    var mouseRegion = MouseRegion(
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
    _hideTimer = Timer(const Duration(milliseconds: 100), () {
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
    var boxDecoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(AthenaRadius.menu),
      boxShadow: AthenaShadow.overlay(colors.shadow),
    );
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.submenuItems,
    );
    var container = Container(
      decoration: boxDecoration,
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
  static DesktopContextMenuManager instance = DesktopContextMenuManager();

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
    var callback = _onDismissed;
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

  /// 弹在 [anchor] 上方的选择菜单能用的最大高度：Claude 的选择器就是一小段
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
    var width = DesktopContextMenuConfiguration.widthOf(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // 浮层不在 Material 之下，文字样式要写全（含 decoration）
        style: AthenaTextStyle.caption.copyWith(
          color: colors.textWeak,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 菜单分组之间的 1px 细线（Claude 在 Archive / Delete 之前有一条）。
class DesktopContextMenuSeparator extends StatelessWidget {
  const DesktopContextMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var width = DesktopContextMenuConfiguration.widthOf(context);
    return Container(
      width: width,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colors.border,
    );
  }
}
