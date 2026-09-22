/// 设置面板的外壳与布局容器。
///
/// [AthenaSettingsPanel] 是居中浮层 + 遮罩（版式与实测值见 `theme/athena_settings.dart`），
/// [AthenaSettingsPane] 是内容区，[AthenaSettingsSection] / [AthenaSettingsGroup] 负责分区
/// 与行分组。行内控件见 `control.dart`，行为组件见 `row.dart`。
library;

import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/widget/button.dart';
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
      child: Focus(autofocus: true, child: Stack(children: children)),
    );
  }

  /// 遮罩只吸收点击，**不关闭面板**：Athena 的设置行有显式 Save，
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
                child: AthenaGhostIconButton(
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return ColoredBox(
      color: colors.surfaceMobile,
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var titleStyle = TextStyle(
      color: colors.textPrimary,
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
      padding: EdgeInsets.only(top: first ? 0 : AthenaSettings.sectionGap),
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var spacer = Container(height: 1, color: colors.neutralRule);
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
