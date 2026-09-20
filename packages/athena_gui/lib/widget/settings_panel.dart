import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// 设置面板外壳：居中浮层 + 遮罩，版式取自 Claude 桌面端的设置。
///
/// 实测（1296×783 逻辑窗口）：面板 1026×695，左右各留 135、上下各留 44，
/// 圆角 12；面板外量到 `#979795`，正是画布 `#FCFCFB` 压 40% 黑。
/// 面板内左侧是导航、右侧是内容区，关闭按钮浮在内容区右上角。
class AthenaSettingsPanel extends StatelessWidget {
  final Widget nav;
  final Widget content;
  final VoidCallback? onClose;
  const AthenaSettingsPanel({
    super.key,
    required this.nav,
    required this.content,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildScrim(context),
      Positioned.fill(child: Center(child: _buildPanel(context))),
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => onClose?.call(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(children: children),
      ),
    );
  }

  /// 遮罩只吸收点击，**不关闭面板**：Athena 的设置行有显式 Save，
  /// 误触遮罩会丢掉未保存的编辑。关闭走右上角的 X 或 Esc。
  Widget _buildScrim(BuildContext context) {
    final settings = settingsColorsOf(context);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(color: settings.scrim),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.panel,
      borderRadius: BorderRadius.circular(AthenaSettings.panelRadius),
      // Claude 实测：面板外的阴影很窄（约 10px 内衰减完，紧贴边缘最深），
      // 不是 overlay 那种 28px 大范围投影。
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var margin = AthenaSettings.panelMarginVertical;
        var width = (constraints.maxWidth - 64).clamp(
          320.0,
          AthenaSettings.panelMaxWidth,
        );
        var height = (constraints.maxHeight - margin * 2).clamp(240.0, 4000.0);
        var closeButton = onClose == null
            ? null
            : Positioned(
                top: 15,
                right: 15,
                child: AthenaSettingsIconButton(
                  icon: HugeIcons.strokeRoundedCancel01,
                  onTap: onClose,
                ),
              );
        return Container(
          width: width,
          height: height,
          decoration: decoration,
          // 面板内必须有 Material：设置路由是**非透明**路由，没有 Scaffold，
          // 而内容区里的输入框（TextField）需要 Material 祖先。
          child: Material(
            color: settings.panel,
            borderRadius: BorderRadius.circular(AthenaSettings.panelRadius),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Row(children: [nav, Expanded(child: content)]),
                if (closeButton != null) closeButton,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 设置内容区：纯白底 + 24 内边距 + 可滚动。
///
/// 实测内容区底色是**纯白** `#FFFFFF`（比导航的 `#FCFCFB` 更白），
/// 左右内边距 24。
class AthenaSettingsPane extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const AthenaSettingsPane({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(AthenaSettings.panePadding),
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    return ColoredBox(
      color: settings.panel,
      child: ListView(padding: padding, children: children),
    );
  }
}

/// 内容区里的一个分区：标题 + 一组行。
class AthenaSettingsSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  /// 首个分区不加顶部留白。
  final bool first;
  const AthenaSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var titleStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.headingFontSize,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    var header = Row(
      children: [
        Expanded(child: Text(title, style: titleStyle)),
        if (trailing != null) trailing!,
      ],
    );
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : AthenaSettings.sectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: AthenaSettings.headingBottomMargin),
          AthenaSettingsGroup(children: children),
        ],
      ),
    );
  }
}

/// 一组行，行与行之间是 1px 的发丝线。
///
/// 实测分隔线 `#F3F3F3`，只跨内容区的左右内边距（不顶到面板边缘）。
class AthenaSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const AthenaSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var spacer = Container(height: 1, color: settings.rule);
    var merged = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) merged.add(spacer);
      merged.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: merged,
    );
  }
}

/// 一行设置：左侧标签（+ 说明），右侧控件，上下各 16 内边距。
///
/// 实测：标签与说明**同号 14**（大写高都是 10.0），标签半粗近黑、
/// 说明常规灰 `#898781`；行上下内边距 16，行高约 69。
class AthenaSettingsRow extends StatefulWidget {
  final String label;
  final String? description;
  final Widget? control;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  const AthenaSettingsRow({
    super.key,
    required this.label,
    this.description,
    this.control,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<AthenaSettingsRow> createState() => _AthenaSettingsRowState();
}

class _AthenaSettingsRowState extends State<AthenaSettingsRow> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var hasDescription = widget.description != null;
    var labelStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: AthenaSettings.rowLabelWeight,
      height: 1.4,
    );
    var descriptionStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: FontWeight.w400,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: labelStyle),
        if (hasDescription) const SizedBox(height: AthenaSettings.rowLabelGap),
        if (hasDescription)
          Text(widget.description!, style: descriptionStyle),
      ],
    );
    var row = Row(
      crossAxisAlignment: hasDescription
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: labelColumn),
        if (widget.control != null) const SizedBox(width: 24),
        if (widget.control != null) widget.control!,
      ],
    );
    var content = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AthenaSettings.rowPaddingVertical,
      ),
      child: row,
    );
    if (widget.onTap == null && widget.onSecondaryTap == null) return content;
    // 可点行的 hover 底用设置面板的中性灰（Claude 的侧栏 hover 是暖灰，
    // 白底上会偏黄，这里沿用面板自己的中性灰）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: hover ? settings.rule : Colors.transparent,
            borderRadius: BorderRadius.circular(AthenaRadius.row),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AthenaSettings.rowPaddingVertical,
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// 只读的「标签 / 值」行，用于经验详情这类没有控件的元信息。
class AthenaSettingsValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  const AthenaSettingsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 96,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var labelStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    var valueStyle = TextStyle(
      color: settings.navSelectedText,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    var children = [
      SizedBox(width: labelWidth, child: Text(label, style: labelStyle)),
      Expanded(child: Text(value, style: valueStyle)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: children),
    );
  }
}

/// 分段控件（Claude 的 segmented control）。
///
/// 实测：轨道 `#F3F3F3` 无描边、高 32、圆角 8；选中块是**纯白填充 +
/// 1px `#E7E7E7` 描边**并**铺满轨道高**（不是内缩的小块）；
/// 选中文字 12 半粗近黑，未选中 12 常规灰 `#898781`。
class AthenaSettingsSegmented<T> extends StatelessWidget {
  final List<AthenaSegmentOption<T>> options;
  final T selected;
  final void Function(T value)? onChanged;
  const AthenaSettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.controlTrack,
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var children = [
      for (final option in options) _buildSegment(context, option),
    ];
    return Container(
      height: AthenaSettings.controlHeight,
      decoration: decoration,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildSegment(BuildContext context, AthenaSegmentOption<T> option) {
    final settings = settingsColorsOf(context);
    var isSelected = option.value == selected;
    var decoration = BoxDecoration(
      color: isSelected ? settings.controlFill : Colors.transparent,
      border: isSelected
          ? Border.all(color: settings.controlBorder)
          : Border.all(color: Colors.transparent),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var textStyle = TextStyle(
      color: isSelected ? settings.navSelectedText : settings.navMuted,
      fontSize: AthenaSettings.segmentFontSize,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    );
    var segment = AnimatedContainer(
      alignment: Alignment.center,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(option.label, style: textStyle, maxLines: 1),
    );
    if (onChanged == null) return segment;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged?.call(option.value),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: segment),
    );
  }
}

/// 分段控件的一个选项。
class AthenaSegmentOption<T> {
  final T value;
  final String label;
  const AthenaSegmentOption({required this.value, required this.label});
}

/// 列表行：用于设置页里的条目列表（Provider / Sentinel / Skill / Experience）。
///
/// 它是**内容列表**不是导航：白底、行间 1px 发丝线、没有圆角块。
/// 选中底 `#E3E3E2`，hover 底 `#F3F3F3`。
class AthenaSettingsListItem extends StatefulWidget {
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTap;
  const AthenaSettingsListItem({
    super.key,
    required this.label,
    this.selected = false,
    this.trailing,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<AthenaSettingsListItem> createState() => _AthenaSettingsListItemState();
}

class _AthenaSettingsListItemState extends State<AthenaSettingsListItem> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var contentColor = widget.selected
        ? settings.navSelectedText
        : settings.navText;
    var background = widget.selected
        ? settings.navSelected
        : hover
        ? settings.rule
        : settings.rule.withValues(alpha: 0);
    var textStyle = TextStyle(
      color: contentColor,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
    );
    var container = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: settings.rule)),
      ),
      duration: const Duration(milliseconds: 120),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.onSecondaryTap,
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

/// 设置页里的条目列表列（Provider / Sentinel / Skill / Experience）。
///
/// 它**不是导航**：底色与内容区同为纯白，靠右侧 1px `#E4E4E3` 分界，
/// 行与行之间是 1px 发丝线，没有圆角选中块。
class AthenaSettingsListColumn extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final List<Widget> children;
  final Widget? footer;

  /// 与右键菜单的偏移约定保持一致（`Offset(240, 50)`）。
  final double width;
  const AthenaSettingsListColumn({
    super.key,
    required this.title,
    required this.children,
    this.onAdd,
    this.footer,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var titleStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.navGroupFontSize,
      height: 1.3,
    );
    var header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: titleStyle)),
          if (onAdd != null)
            AthenaSettingsIconButton(
              box: 24,
              icon: HugeIcons.strokeRoundedAdd01,
              iconSize: 14,
              onTap: onAdd,
            ),
        ],
      ),
    );
    var decoration = BoxDecoration(
      border: Border(right: BorderSide(color: settings.navDivider)),
    );
    var children2 = [
      header,
      Expanded(child: ListView(padding: EdgeInsets.zero, children: children)),
      if (footer != null) footer!,
    ];
    return Container(
      width: width,
      decoration: decoration,
      child: Column(children: children2),
    );
  }
}

/// 设置里的下拉选择（Claude 的 select 控件）。
///
/// 实测：白底、1px `#E7E7E7` 描边、高 32、圆角 8、文字 14 近黑，
/// 右端一个 chevron。它只管外观，点开的是调用方给的弹层。
class AthenaSettingsSelect extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const AthenaSettingsSelect({super.key, required this.label, this.onTap});

  @override
  State<AthenaSettingsSelect> createState() => _AthenaSettingsSelectState();
}

class _AthenaSettingsSelectState extends State<AthenaSettingsSelect> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var decoration = BoxDecoration(
      color: settings.controlFill,
      border: Border.all(color: settings.controlBorder),
      borderRadius: BorderRadius.circular(AthenaSettings.controlRadius),
    );
    var label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: settings.navSelectedText,
        fontSize: AthenaSettings.controlFontSize,
        height: 1.3,
      ),
    );
    var chevron = Icon(
      HugeIcons.strokeRoundedArrowDown01,
      color: settings.navMuted,
      size: 14,
    );
    var content = AnimatedContainer(
      alignment: Alignment.centerLeft,
      decoration: decoration,
      duration: const Duration(milliseconds: 120),
      height: AthenaSettings.controlHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.controlPaddingHorizontal,
      ),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          chevron,
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: content,
      ),
    );
  }
}

/// 空态文字（No Skills / No Sentinels ...）。
class AthenaSettingsEmptyState extends StatelessWidget {
  final String text;
  const AthenaSettingsEmptyState({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var textStyle = TextStyle(
      color: settings.navMuted,
      fontSize: AthenaSettings.rowFontSize,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text(text, style: textStyle)),
    );
  }
}

/// 设置面板里的 ghost 图标按钮（关闭、新增）。
///
/// Claude 的控件语言：静止无底色，hover 填充前景色 5%，圆角 7。
class AthenaSettingsIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double box;
  final double iconSize;
  const AthenaSettingsIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.box = 28,
    this.iconSize = AthenaSettings.closeIconSize,
  });

  @override
  State<AthenaSettingsIconButton> createState() =>
      _AthenaSettingsIconButtonState();
}

class _AthenaSettingsIconButtonState extends State<AthenaSettingsIconButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsColorsOf(context);
    var icon = Icon(
      widget.icon,
      color: settings.navText,
      size: widget.iconSize,
    );
    var container = AnimatedContainer(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hover ? settings.rule : Colors.transparent,
        borderRadius: BorderRadius.circular(AthenaRadius.row),
      ),
      duration: const Duration(milliseconds: 120),
      height: widget.box,
      width: widget.box,
      child: icon,
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
