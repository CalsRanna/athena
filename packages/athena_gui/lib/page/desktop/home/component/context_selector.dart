import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 草稿和已有会话共用当前保留策略，避免切换会话后仍显示旧状态。
class DesktopContextSelector extends StatelessWidget {
  final int currentRetention;
  final void Function(int)? onSelected;

  const DesktopContextSelector({
    super.key,
    required this.currentRetention,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = currentRetention != 0;
    return AthenaContextChip(
      leading: Icon(enabled ? LucideIcons.clock4 : LucideIcons.clockFading),
      label: enabled ? 'Context on' : 'Context off',
      filled: false,
      onTap: () => DesktopContextMenuManager.instance.show(
        context,
        _ContextMenu(
          anchor: contextMenuAnchorOf(context),
          enabled: enabled,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

class _ContextMenu extends StatelessWidget {
  final Rect anchor;
  final bool enabled;
  final void Function(int)? onSelected;

  const _ContextMenu({
    required this.anchor,
    required this.enabled,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const width = 280.0;
    return DesktopContextMenu(
      // 面板左右各有 4 内边距，整体右边与触发 chip 对齐。
      offset: Offset(anchor.right - width - 8, anchor.top - 8),
      upward: true,
      width: width,
      children: [
        const DesktopContextMenuGroupLabel(text: 'Conversation context'),
        _ContextOption(
          title: 'Use chat history',
          description: 'Include earlier messages in this chat.',
          selected: enabled,
          onTap: () => onSelected?.call(-1),
        ),
        _ContextOption(
          title: 'Current message only',
          description: 'Leave out earlier messages in this chat.',
          selected: !enabled,
          onTap: () => onSelected?.call(0),
        ),
        const DesktopContextMenuSeparator(),
        const _ContextMenuHint(),
      ],
    );
  }
}

class _ContextOption extends StatefulWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ContextOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ContextOption> createState() => _ContextOptionState();
}

class _ContextOptionState extends State<_ContextOption> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          DesktopContextMenuManager.instance.dismiss();
          widget.onTap();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hover = true),
          onExit: (_) => setState(() => hover = false),
          child: Container(
            width: DesktopContextMenuConfiguration.widthOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hover ? colors.surfaceHover : null,
              borderRadius: BorderRadius.circular(AthenaRadius.row),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AthenaTextStyle.row.copyWith(
                          color: colors.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        style: AthenaTextStyle.caption.copyWith(
                          color: colors.textSecondary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 两档都留出勾选位置，说明文字不会随选中状态换行。
                SizedBox(
                  width: 16,
                  child: widget.selected
                      ? Icon(
                          LucideIcons.check,
                          size: 16,
                          color: colors.textPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuHint extends StatelessWidget {
  const _ContextMenuHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return SizedBox(
      width: DesktopContextMenuConfiguration.widthOf(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Text(
          'Applies to future messages in this chat.',
          style: AthenaTextStyle.caption.copyWith(
            color: colors.textSecondary,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
