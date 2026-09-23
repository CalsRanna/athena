import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';

/// 步骤类卡片（工具 / 推理 / 压缩 / 步骤组）共用的视觉原语。
///
/// 这些卡片没有底板，直接坐在页面底色上，因此统一用 `textSecondary` 前景、
/// 15 号图标、单行省略文案；运行中的折叠头带一条流动 shimmer 高光。
/// 之前同一套「Material > InkWell > Shimmer > Row[Icon, Text]」在五处各写了
/// 一份，此处合并为唯一实现，只保留头部与结果正文两个原语。

/// 步骤头部圆角：与展开区对齐，比 [AthenaRadius.row] 略大以匹配 15 号图标。
const kStepHeaderRadius = 8.0;

/// 步骤头部与结果正文的字号。

/// 折叠头：图标 + 单行文案（[mono] 时等宽）+ 运行中 shimmer。
///
/// [onTap] 为 null 时不可点（光标为普通箭头），用于结果未返回或纯展示的头。
///
/// 静止前景是次级文字色；**可点的头在 hover 时整条（图标 + 文案）提亮到正文色**
/// `textPrimary`——与 [AthenaTextButton] 的 `textSecondary → textPrimary` 同一口径：
/// 前景提亮即"这里能点开"。运行中的头由 shimmer 的 `srcIn` 统一改色，彼时提亮被
/// 覆盖，观感以 shimmer 为准（无妨：此时它本就没有可展开的正文）。
class StepHeader extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool mono;
  final bool running;
  final VoidCallback? onTap;

  const StepHeader({
    super.key,
    required this.icon,
    required this.label,
    this.mono = false,
    this.running = false,
    this.onTap,
  });

  @override
  State<StepHeader> createState() => _StepHeaderState();
}

class _StepHeaderState extends State<StepHeader> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final interactive = widget.onTap != null;
    final foreground = interactive && _hovered
        ? colors.textPrimary
        : colors.textSecondary;
    final style = widget.mono
        ? athenaMono(color: foreground)
        : AthenaTextStyle.caption.copyWith(color: foreground);
    return MouseRegion(
      // 不可点的头不挂 hover 回调：光标已是普通箭头，再提亮就成了假的可点信号。
      onEnter: interactive ? (_) => _setHovered(true) : null,
      onExit: interactive ? (_) => _setHovered(false) : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kStepHeaderRadius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(kStepHeaderRadius),
          mouseCursor: interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: StepHeaderShimmer(
            active: widget.running,
            child: Row(
              children: [
                Icon(widget.icon, size: 15, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 展开后的结果正文：等宽、最多 10 行、`Error:` 前缀标红；点击整块收起。
class StepResultBody extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const StepResultBody({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final isError = text.startsWith('Error:');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: athenaMono(
            color: isError ? colors.statusError : colors.textSecondary,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

/// 仅在步骤执行期间为头部前景提供低对比度的流动高光。
class StepHeaderShimmer extends StatefulWidget {
  final bool active;
  final Widget child;

  const StepHeaderShimmer({
    super.key,
    required this.active,
    required this.child,
  });

  /// shimmer 颜色：由主题的页面前景色只调透明度得来的高光与底光。
  ///
  /// `srcIn` 会把子树整块换成这里的颜色，所以**不能写死白色**：卡面无底板后
  /// 这些 header 直接坐在页面底色上，浅色主题里写死的白就是「白底白字」，
  /// 折叠头整个看不见（深色主题下 `textPrimary` 本就是白，观感不变）。
  @visibleForTesting
  static ({Color base, Color highlight}) colorsFor(AthenaColors colors) {
    final shimmer = colors.textPrimary;
    return (
      base: shimmer.withValues(alpha: 0.45),
      highlight: shimmer.withValues(alpha: 0.95),
    );
  }

  @override
  State<StepHeaderShimmer> createState() => _StepHeaderShimmerState();
}

class _StepHeaderShimmerState extends State<StepHeaderShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(StepHeaderShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && !_animationsDisabled) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _animationsDisabled) return widget.child;
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final (:base, :highlight) = StepHeaderShimmer.colorsFor(colors);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final offset = -2.0 + (_controller.value * 4.0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(offset - 1, 0),
            end: Alignment(offset + 1, 0),
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
