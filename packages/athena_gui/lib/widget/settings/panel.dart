/// 设置面板的外壳与布局容器。
///
/// [AthenaSettingsPanel] 是居中浮层 + 遮罩（版式与实测值见 `theme/athena_settings.dart`），
/// [AthenaSettingsPane] 是内容区（可带标题带里的返回链接与底部粘性栏），
/// [AthenaSettingsSection] / [AthenaSettingsGroup] 负责分区与行分组。
/// 行内控件见 `control.dart`，行类组件见 `row.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_icons.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 设置面板外壳：居中浮层 + 遮罩。
///
/// 实测（1296×783 逻辑窗口）：面板 1026×695，左右各留 135、上下各留 44，
/// 圆角统一为 16；遮罩与表面颜色跟随 Athena 青瓷色板。
/// 面板内左侧是导航、右侧是内容区，关闭按钮浮在内容区右上角的**标题带**里
/// （内容区顶部留出 [AthenaSettings.paneTopPadding]，分区标题从标题带下方
/// 开始，不会与关闭键同一水平线）。
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
      child: Focus(autofocus: true, child: Stack(children: children)),
    );
  }

  /// 遮罩只吸收点击，**不关闭面板**：Sentinel / Skill 的编辑区有显式 Save，
  /// 误触遮罩会丢掉未保存的编辑。关闭走右上角的 X 或 Esc。
  Widget _buildScrim(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(color: colors.scrim),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var decoration = BoxDecoration(
      color: colors.surfaceMobile,
      borderRadius: BorderRadius.circular(AthenaSettings.panelRadius),
      boxShadow: AthenaShadow.modal(colors.shadow),
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
                top: AthenaSettings.closeInset,
                right: AthenaSettings.closeInset,
                child: AthenaGhostIconButton(
                  icon: LucideIcons.x,
                  iconSize: AthenaSettings.closeIconSize,
                  onTap: onClose,
                ),
              );
        return Container(
          width: width,
          height: height,
          decoration: decoration,
          // 两种主题都保留前景装饰：从 null 切到非 null 会改变 Container
          // 的子树层级，销毁右侧 AutoRouter，丢失已消费的子路由与页面状态。
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AthenaSettings.panelRadius),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? colors.border
                  : colors.border.withValues(alpha: 0),
            ),
          ),
          // 面板内必须有 Material：设置路由是**非透明**路由，没有 Scaffold，
          // 而内容区里的输入框（TextField）需要 Material 祖先。
          child: Material(
            color: colors.surfaceMobile,
            borderRadius: BorderRadius.circular(AthenaSettings.panelRadius),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Row(
                  children: [
                    nav,
                    Expanded(child: content),
                  ],
                ),
                if (closeButton != null) closeButton,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 设置内容区：浮层底色 + 可滚动 + 顶部标题带 + 可选底部粘性栏。
///
/// 内容区使用 surfaceMobile，与导航的 surfacePanel 区分，文字列左右内缩 24。
/// 列表本身按 `24 − 8` 内缩，每一行自带 8 的水平内边距
/// （见 [AthenaSettings.rowInset]），这样可点行的 hover 底会比文字列宽一圈，
/// 而所有行的文字仍落在同一条 24 的左缘上。
///
/// [header] 放在顶部标题带里（与右上角关闭键同一水平线），用于钻取页的
/// 返回链接；[footer] 固定在底部不随内容滚动，用于「未保存改动」的保存栏。
class AthenaSettingsPane extends StatelessWidget {
  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  const AthenaSettingsPane({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    const horizontal = AthenaSettings.panePadding - AthenaSettings.rowInset;
    var list = ListView(
      padding: const EdgeInsets.fromLTRB(
        horizontal,
        AthenaSettings.panePadding,
        horizontal,
        AthenaSettings.paneBottomPadding,
      ),
      children: children,
    );
    Widget body = list;
    if (footer != null) {
      body = Column(
        children: [
          Expanded(child: list),
          footer!,
        ],
      );
    }
    var stackChildren = [
      // 标题带留在滚动视口外，不能用随内容滚走的 ListView 顶部 padding。
      Positioned.fill(top: AthenaSettings.paneTopPadding, child: body),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: AthenaSettings.paneTopPadding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.neutralHairline)),
          ),
        ),
      ),
      if (header != null)
        Positioned(
          top: AthenaSettings.closeInset,
          left: AthenaSettings.panePadding - AthenaSettings.rowInset,
          // 给右上角的关闭键留位置
          right: AthenaSettings.closeInset + 28 + 12,
          child: Align(alignment: Alignment.centerLeft, child: header!),
        ),
    ];
    return ColoredBox(
      color: colors.surfaceMobile,
      child: Stack(children: stackChildren),
    );
  }
}

/// 标题带里的返回链接（钻取页：`← Providers`）。
///
/// ghost 样式：静止无底，hover 前景色 5%，高 28、圆角 8；图标 14 +
/// 标签 14 `textRowLabel`。
class AthenaSettingsBackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AthenaSettingsBackLink({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textRowLabel,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaFontSize.bodyHeight,
    );
    var children = [
      Icon(
        AthenaIcons.back,
        color: colors.textRowLabel,
        size: AthenaIcon.inlineSize,
      ),
      const SizedBox(width: 6),
      Text(label, maxLines: 1, style: textStyle),
    ];
    return AthenaHover(
      onTap: onTap,
      cursor: SystemMouseCursors.click,
      builder: (context, hover) => AnimatedContainer(
        decoration: BoxDecoration(
          // 静止态用目标色的 0 透明度版；透明黑插值会先闪深色
          color: colors.textPrimary.withValues(alpha: hover ? 0.05 : 0),
          borderRadius: BorderRadius.circular(AthenaSettings.navRowRadius),
        ),
        duration: AthenaMotion.hover,
        height: 28,
        padding: const EdgeInsets.symmetric(
          horizontal: AthenaSettings.rowInset,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// 内容区里的一个分区：标题（+ 一句说明 + 右侧动作）+ 一组行。
class AthenaSettingsSection extends StatelessWidget {
  final String title;

  /// 标题下方的一句说明（`textWeak`），用于交代这一组设置管什么。
  final String? description;

  /// 标题行右端的动作（开关、`Add` 按钮之类）。
  final Widget? trailing;
  final List<Widget> children;

  /// 首个分区不加顶部留白。
  final bool first;
  const AthenaSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.headingFontSize,
      fontWeight: FontWeight.w600,
      height: AthenaFontSize.titleHeight,
    );
    var descriptionStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var titleRow = Row(
      children: [
        Expanded(child: Text(title, style: titleStyle)),
        if (trailing != null) trailing!,
      ],
    );
    var header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AthenaSettings.rowInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleRow,
          if (description != null) const SizedBox(height: 6),
          if (description != null) Text(description!, style: descriptionStyle),
        ],
      ),
    );
    // 有说明时说明本身已把标题与首行隔开，留白收窄一档。
    var gap = description == null ? AthenaSettings.headingBottomMargin : 16.0;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : AthenaSettings.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: gap),
          AthenaSettingsGroup(children: children),
        ],
      ),
    );
  }
}

/// 一组行，行与行之间是 1px 的发丝线。
///
/// 实测分隔线 `#F3F3F3`，只跨文字列（与行的 hover 底不同宽）。
class AthenaSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const AthenaSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var spacer = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AthenaSettings.rowInset),
      child: Container(height: 1, color: colors.neutralRule),
    );
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

/// 把任意内容对齐到文字列（补上行自带的那 8 内缩）。
///
/// 多行输入、段落、标签组这类不是「行」的内容放进分区时用它包一层。
class AthenaSettingsInset extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AthenaSettingsInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AthenaSettings.rowInset,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}

/// 底部粘性的「未保存改动」栏：一句提示 + Discard + Save。
///
/// 只在编辑区脏了才出现；上边一条 `neutralBorder`，底色与内容区同为纯白。
class AthenaSettingsSaveBar extends StatelessWidget {
  final String message;
  final VoidCallback? onDiscard;
  final VoidCallback? onSave;
  final String saveLabel;
  const AthenaSettingsSaveBar({
    super.key,
    this.message = 'You have unsaved changes',
    this.onDiscard,
    this.onSave,
    this.saveLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaFontSize.bodyHeight,
    );
    var children = [
      Expanded(child: Text(message, maxLines: 1, style: textStyle)),
      AthenaSecondaryButton.small(
        onTap: onDiscard,
        child: const Text('Discard'),
      ),
      const SizedBox(width: AthenaSpace.sm),
      AthenaPrimaryButton.small(onTap: onSave, child: Text(saveLabel)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMobile,
        border: Border(top: BorderSide(color: colors.neutralBorder)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AthenaSettings.panePadding,
        vertical: AthenaSpace.md,
      ),
      child: Row(children: children),
    );
  }
}

/// 空态：图标 + 标题 + 一句提示（+ 可选动作），居中放在分区里。
class AthenaSettingsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  const AthenaSettingsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: AthenaSettings.rowLabelWeight,
      height: AthenaFontSize.bodyHeight,
    );
    var hintStyle = TextStyle(
      color: colors.textWeak,
      fontSize: AthenaSettings.rowFontSize,
      height: AthenaSettings.rowDescriptionHeight,
    );
    var children = [
      Icon(
        icon,
        color: colors.iconSecondary,
        size: AthenaSettings.emptyStateIconSize,
      ),
      const SizedBox(height: AthenaSpace.md),
      Text(title, style: titleStyle, textAlign: TextAlign.center),
      if (hint != null) const SizedBox(height: AthenaSpace.xs),
      if (hint != null)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(hint!, style: hintStyle, textAlign: TextAlign.center),
        ),
      if (action != null) const SizedBox(height: AthenaSpace.lg),
      if (action != null) action!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
