import 'package:athena_core/util/tool_args_formatter.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ToolCard extends StatefulWidget {
  final String toolName;
  final String arguments;
  final String? result;

  const ToolCard({
    super.key,
    required this.toolName,
    required this.arguments,
    this.result,
  });

  bool get hasResult => result != null;

  @override
  State<ToolCard> createState() => _ToolCardState();

  // ─── 静态工具函数 ────────────────────────────────────────

  /// 工具图标映射（HugeIcons strokeRounded 系列）。
  static IconData toolIcon(String toolName) {
    return switch (toolName) {
      'bash' || 'powershell' => HugeIcons.strokeRoundedCommandLine,
      'file_read' => HugeIcons.strokeRoundedFile01,
      'file_write' || 'file_update' => HugeIcons.strokeRoundedPencilEdit02,
      'web_fetch' => HugeIcons.strokeRoundedGlobe,
      'web_search' => HugeIcons.strokeRoundedSearch01,
      'skill' => HugeIcons.strokeRoundedBook01,
      'sentinel_evolve' => HugeIcons.strokeRoundedAiBrain01,
      'experience_learn' => HugeIcons.strokeRoundedAiBrain02,
      _ => HugeIcons.strokeRoundedTools,
    };
  }

  /// Shared GUI/TUI preview: call description, key argument, then compact JSON.
  static String argPreview(String toolName, String arguments) =>
      toolArgPreview(toolName, arguments);
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool get _running => !widget.hasResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        if (widget.hasResult && _expanded) _buildContent(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: widget.hasResult
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(_radius),
        mouseCursor: widget.hasResult
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Row(
          children: [
            Expanded(
              child: ToolHeaderShimmer(
                active: _running,
                child: Row(
                  children: [
                    Icon(
                      ToolCard.toolIcon(widget.toolName),
                      size: 15,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    // 描述占满剩余宽度，只有真正超出时才省略
                    Expanded(
                      child: Text(
                        ToolCard.argPreview(widget.toolName, widget.arguments),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: athenaMono(
                          fontSize: _fontSize,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final isError = widget.result!.startsWith('Error:');
    return GestureDetector(
      onTap: () => setState(() => _expanded = false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          widget.result!,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: athenaMono(
            fontSize: _fontSize,
            color: isError ? colors.statusError : colors.textSecondary,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

/// 仅在工具执行期间为 Header 前景提供低对比度的流动高光。
class ToolHeaderShimmer extends StatefulWidget {
  final bool active;
  final Widget child;

  const ToolHeaderShimmer({
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
  State<ToolHeaderShimmer> createState() => _ToolHeaderShimmerState();
}

class _ToolHeaderShimmerState extends State<ToolHeaderShimmer>
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
  void didUpdateWidget(ToolHeaderShimmer oldWidget) {
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
    final (:base, :highlight) = ToolHeaderShimmer.colorsFor(colors);

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
