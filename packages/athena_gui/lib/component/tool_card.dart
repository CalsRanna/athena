import 'dart:convert';

import 'package:athena_gui/util/color_util.dart';
import 'package:athena_core/util/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// 工具状态：运行中（无结果）/ 成功 / 失败。
enum _ToolStatus { running, done, error }

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
      'sentinel_evolve' || 'experience_learn' =>
        HugeIcons.strokeRoundedAiBrain01,
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
      'bash' || 'powershell' => 'command',
      'file_read' || 'file_write' || 'file_update' => 'path',
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

  bool get _isDesktop => PlatformUtil.isDesktop;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_isDesktop ? 8 : 12);
    final cardBgColor = _isDesktop ? ColorUtil.FFEDEDED : ColorUtil.FF616161;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(borderRadius: borderRadius, color: cardBgColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(borderRadius),
          if (widget.hasResult && _expanded) _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader(BorderRadius outerRadius) {
    final collapsedRadius = BorderRadius.circular(_isDesktop ? 8 : 12);
    final expandedRadius = BorderRadius.only(
      topLeft: Radius.circular(_isDesktop ? 8 : 12),
      topRight: Radius.circular(_isDesktop ? 8 : 12),
    );
    final borderRadius = (widget.hasResult && _expanded)
        ? expandedRadius
        : collapsedRadius;
    final headerBgColor = _isDesktop ? ColorUtil.FFE0E0E0 : ColorUtil.FF757575;
    final fontSize = _isDesktop ? 12.0 : 11.0;
    final status = _status;

    return GestureDetector(
      onTap: widget.hasResult
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: headerBgColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              ToolCard.toolIcon(widget.toolName),
              size: _isDesktop ? 15 : 13,
              color: _isDesktop
                  ? ColorUtil.FF616161
                  : ColorUtil.FFE0E0E0,
            ),
            const SizedBox(width: 8),
            Text(
              widget.toolName,
              style: GoogleFonts.firaCode(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ToolCard.argPreview(widget.toolName, widget.arguments),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.firaCode(
                  fontSize: fontSize,
                  color: _isDesktop
                      ? ColorUtil.FF616161
                      : ColorUtil.FFC2C2C2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStatus(status),
            if (widget.hasResult) ...[
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? HugeIcons.strokeRoundedArrowDown01
                    : HugeIcons.strokeRoundedArrowRight01,
                size: _isDesktop ? 16 : 14,
                color: _isDesktop
                    ? ColorUtil.FF616161
                    : ColorUtil.FFE0E0E0,
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ToolStatus get _status {
    final result = widget.result;
    if (result == null) return _ToolStatus.running;
    if (result.startsWith('Error:')) return _ToolStatus.error;
    return _ToolStatus.done;
  }

  Widget _buildStatus(_ToolStatus status) {
    final fontSize = _isDesktop ? 12.0 : 11.0;
    // 状态色为 accent 色（绿 A7BA88 / 红 E38B8B）的加深变体，
    // 保证在浅灰 header 上的可读性。
    const doneColor = Color(0xFF8AA371);
    const errorColor = Color(0xFFC05555);
    final runningColor = _isDesktop
        ? ColorUtil.FF616161
        : ColorUtil.FFC2C2C2;
    final iconColor = switch (status) {
      _ToolStatus.running => runningColor,
      _ToolStatus.done => doneColor,
      _ToolStatus.error => errorColor,
    };
    final label = switch (status) {
      _ToolStatus.running => 'running',
      _ToolStatus.done => 'done',
      _ToolStatus.error => 'error',
    };
    final labelColor = switch (status) {
      _ToolStatus.running => runningColor,
      _ToolStatus.done => doneColor,
      _ToolStatus.error => errorColor,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == _ToolStatus.running)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: iconColor,
            ),
          )
        else
          Icon(
            status == _ToolStatus.done
                ? HugeIcons.strokeRoundedTick02
                : HugeIcons.strokeRoundedCancelCircle,
            size: _isDesktop ? 15 : 13,
            color: iconColor,
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: fontSize,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final fontSize = _isDesktop ? 12.0 : 11.0;
    final isError = _status == _ToolStatus.error;
    return GestureDetector(
      onTap: widget.hasResult
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ColorUtil.FFEDEDED,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(_isDesktop ? 8 : 12),
            bottomRight: Radius.circular(_isDesktop ? 8 : 12),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            widget.result!,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.firaCode(
              fontSize: fontSize,
              color: isError ? const Color(0xFFC05555) : ColorUtil.FF282F32,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
