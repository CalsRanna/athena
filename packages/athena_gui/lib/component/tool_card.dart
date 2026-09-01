import 'dart:convert';

import 'package:athena_core/agent/permission/permission_rule.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// 参数预览：优先提取关键字段（command/path/url/query），其余原样 JSON。
  static String argPreview(String toolName, String arguments) {
    Map<String, dynamic>? args;
    try {
      args = jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return arguments;
    }

    final keyField = switch (toolName) {
      _ when kShellToolNames.contains(toolName) => 'command',
      _ when kFileToolNames.contains(toolName) => 'path',
      'web_fetch' => 'url',
      'web_search' => 'query',
      _ => null,
    };
    if (keyField != null && args[keyField] is String) {
      return args[keyField] as String;
    }
    return arguments;
  }
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  static const _radius = 8.0;
  static const _fontSize = 12.0;

  bool get _running => !widget.hasResult;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.hasResult && _expanded) _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final foreground = colors.textSecondaryOnRaised;

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
                    Flexible(
                      child: Text(
                        widget.toolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.firaCode(
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ToolCard.argPreview(widget.toolName, widget.arguments),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.firaCode(
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
        margin: const EdgeInsets.fromLTRB(10, 2, 4, 4),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Text(
          widget.result!,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.firaCode(
            fontSize: _fontSize,
            color: isError ? colors.statusError : colors.textSecondaryOnRaised,
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
    final base = colors.textSecondaryOnRaised.withValues(alpha: 0.45);
    final highlight = colors.textSecondaryOnRaised.withValues(alpha: 0.95);

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
