import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/reasoning_effort_dialog.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 工具栏上的推理强度文字（Claude 的 `High`）。只负责显示：点击由外层
/// `_SquishButton` 接管，弹出 [DesktopReasoningEffortMenu]。
class DesktopReasoningEffortLabel extends StatelessWidget {
  final String current;
  const DesktopReasoningEffortLabel({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Text(
      reasoningEffortLabel(current),
      // 与模型名同字号同字重（Claude 的 `High` 是常规字重）
      style: AthenaTextStyle.body.copyWith(color: colors.textPrimary),
    );
  }
}

/// 推理强度面板：对齐 Claude 的 Effort 弹层。
///
/// 标题行「Effort + 当前档」与帮助图标、`Faster / Smarter` 两端标注、
/// 一条五档滑杆（[reasoningEffortOptions] 从弱到强）。点或拖滑杆立即生效，
/// 面板不关；锚在触发块 [anchor] 上方、右边与它对齐。
class DesktopReasoningEffortMenu extends StatefulWidget {
  final Rect anchor;
  final String current;
  final void Function(String)? onSelected;

  const DesktopReasoningEffortMenu({
    super.key,
    required this.anchor,
    required this.current,
    this.onSelected,
  });

  static void show(
    BuildContext context,
    Rect anchor, {
    required String current,
    void Function(String)? onSelected,
  }) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopReasoningEffortMenu(
        anchor: anchor,
        current: current,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<DesktopReasoningEffortMenu> createState() =>
      _DesktopReasoningEffortMenuState();
}

class _DesktopReasoningEffortMenuState
    extends State<DesktopReasoningEffortMenu> {
  static const _contentWidth = 248.0;

  late int index = _indexOf(widget.current);

  static int _indexOf(String value) {
    final i = reasoningEffortOptions.indexWhere((o) => o.$1 == value);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchor;
    return DesktopContextMenu(
      // 面板自带 4 内边距，左边要比"右对齐"再让出 8
      offset: Offset(anchor.right - _contentWidth - 8, anchor.top - 8),
      upward: true,
      width: _contentWidth,
      children: [
        // 面板是设置面，不是动作列表：点在文字/空白上不该把它关掉
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: _EffortPanel(index: index, onChanged: handleChanged),
        ),
      ],
    );
  }

  void handleChanged(int value) {
    if (value == index) return;
    setState(() => index = value);
    widget.onSelected?.call(reasoningEffortOptions[value].$1);
  }
}

class _EffortPanel extends StatelessWidget {
  final int index;
  final void Function(int) onChanged;
  const _EffortPanel({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final titleStyle = AthenaTextStyle.row.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    final valueStyle = AthenaTextStyle.row.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
    );
    final endStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textSecondary,
      decoration: TextDecoration.none,
    );
    final header = Row(
      children: [
        Text('Effort', style: titleStyle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reasoningEffortOptions[index].$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
        _HelpIcon(),
      ],
    );
    final ends = Row(
      children: [
        Text('Faster', style: endStyle),
        const Spacer(),
        Text('Smarter', style: endStyle),
      ],
    );
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: 12),
            ends,
            const SizedBox(height: 6),
            _EffortSlider(
              index: index,
              count: reasoningEffortOptions.length,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// 标题行右端的 `?`：hover 出一句深色 tooltip。
class _HelpIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Tooltip(
      message:
          'Higher effort lets the model think longer before answering. '
          'Applies from the next message.',
      preferBelow: false,
      verticalOffset: 14,
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(AthenaRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      textStyle: AthenaTextStyle.caption.copyWith(color: colors.textOnRaised),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Icon(
          LucideIcons.circleQuestionMark,
          size: 14,
          color: colors.iconSecondary,
        ),
      ),
    );
  }
}

/// 离散滑杆：浅灰胶囊轨道、每档一个小点、当前档一枚带柔阴影的白色圆钮。
/// 点击或水平拖动都按最近的档位吸附。
class _EffortSlider extends StatelessWidget {
  final int index;
  final int count;
  final void Function(int) onChanged;

  const _EffortSlider({
    required this.index,
    required this.count,
    required this.onChanged,
  });

  static const _height = 24.0;
  static const _trackHeight = 14.0;
  static const _knob = 18.0;
  static const _dot = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final step = (width - _knob) / (count - 1);
        double centerOf(int i) => _knob / 2 + i * step;
        void pick(double dx) {
          final i = ((dx - _knob / 2) / step).round().clamp(0, count - 1);
          onChanged(i);
        }

        final track = Center(
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              // 白底面板上的填充与线只从 neutral* 取（DESIGN §2）
              color: colors.neutralRule,
              borderRadius: BorderRadius.circular(AthenaRadius.pill),
            ),
          ),
        );
        final dots = [
          for (var i = 0; i < count; i++)
            Positioned(
              left: centerOf(i) - _dot / 2,
              top: (_height - _dot) / 2,
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: colors.neutralBorderStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ];
        final knob = AnimatedPositioned(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          left: centerOf(index) - _knob / 2,
          top: (_height - _knob) / 2,
          child: Container(
            width: _knob,
            height: _knob,
            decoration: BoxDecoration(
              color: colors.neutralControlFill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.neutralBorder),
              boxShadow: AthenaShadow.raised(colors.shadow),
            ),
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => pick(details.localPosition.dx),
          onHorizontalDragStart: (details) => pick(details.localPosition.dx),
          onHorizontalDragUpdate: (details) => pick(details.localPosition.dx),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              height: _height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: track),
                  ...dots,
                  knob,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
