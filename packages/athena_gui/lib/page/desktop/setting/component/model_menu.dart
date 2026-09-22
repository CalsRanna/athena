import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

/// 设置里「选一个模型」的下拉菜单：锚在 select 控件下方、与它同宽，
/// 按 provider 分组、当前值行尾打钩；条目多时在面板内滚。
///
/// 与 composer 的模型菜单是同一套视觉（`DesktopContextMenu` 面板 + 32 高
/// 条目 + 分组小标题），只是锚定方向不同：设置控件在内容区里，菜单向下
/// 展开更自然，贴近窗底时再翻到上方。
class DesktopSettingModelMenu extends StatelessWidget {
  final Rect anchor;
  final int? selectedId;
  final void Function(ModelEntity)? onSelected;

  /// 允许清空（`No model` 一项）。
  final VoidCallback? onCleared;

  const DesktopSettingModelMenu({
    super.key,
    required this.anchor,
    this.selectedId,
    this.onSelected,
    this.onCleared,
  });

  static void show(
    BuildContext context,
    Rect anchor, {
    int? selectedId,
    void Function(ModelEntity)? onSelected,
    VoidCallback? onCleared,
  }) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopSettingModelMenu(
        anchor: anchor,
        selectedId: selectedId,
        onSelected: onSelected,
        onCleared: onCleared,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = GetIt.instance<ModelViewModel>().groupedEnabledModels.value;
    // 面板自带 4 内边距，条目宽 = 控件宽 − 8 才能让面板外沿与控件同宽
    final width = anchor.width - 8;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final below = screenHeight - anchor.bottom - 16;
    final upward = below < 200 && anchor.top > below;
    final maxHeight = (upward ? anchor.top - 16 : below).clamp(120.0, 360.0);
    final children = <Widget>[
      if (onCleared != null)
        _ModelTile(
          label: 'No model',
          muted: true,
          selected: selectedId == null || selectedId == 0,
          onTap: onCleared,
        ),
      for (final entry in groups.entries) ...[
        DesktopContextMenuGroupLabel(text: entry.key),
        for (final model in entry.value)
          _ModelTile(
            label: model.name,
            reasoning: model.reasoning,
            vision: model.vision,
            selected: model.id == selectedId,
            onTap: () => onSelected?.call(model),
          ),
      ],
      if (groups.isEmpty)
        const _ModelTile(label: 'No enabled models', muted: true),
    ];
    return DesktopContextMenu(
      offset: upward
          ? Offset(anchor.left, anchor.top - 4)
          : Offset(anchor.left, anchor.bottom + 4),
      upward: upward,
      width: width,
      children: [
        DesktopContextMenuList(maxHeight: maxHeight, children: children),
      ],
    );
  }
}

/// 一行模型：名字 + 能力小图标，选中行尾打钩。
class _ModelTile extends StatefulWidget {
  final String label;
  final bool reasoning;
  final bool vision;
  final bool selected;
  final bool muted;
  final void Function()? onTap;

  const _ModelTile({
    required this.label,
    this.reasoning = false,
    this.vision = false,
    this.selected = false,
    this.muted = false,
    this.onTap,
  });

  @override
  State<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final width = DesktopContextMenuConfiguration.widthOf(context);
    // 浮层不在 Material 之下，文字样式要写全（含 decoration），与菜单条目一致
    final nameStyle = AthenaTextStyle.row.copyWith(
      color: widget.muted ? colors.textSecondary : colors.textPrimary,
      decoration: TextDecoration.none,
    );
    final row = Row(
      children: [
        Expanded(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        if (widget.reasoning) ...[
          const SizedBox(width: 8),
          Icon(
            HugeIcons.strokeRoundedBrain02,
            size: 14,
            color: colors.iconSecondary,
          ),
        ],
        if (widget.vision) ...[
          const SizedBox(width: 6),
          Icon(
            HugeIcons.strokeRoundedVision,
            size: 14,
            color: colors.iconSecondary,
          ),
        ],
        if (widget.selected) ...[
          const SizedBox(width: 8),
          Icon(
            HugeIcons.strokeRoundedTick02,
            size: 16,
            color: colors.textPrimary,
          ),
        ],
      ],
    );
    final container = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AthenaRadius.row),
        color: hover && widget.onTap != null ? colors.surfaceHover : null,
      ),
      // 与其他菜单条目同一档：12 × 7，高约 32
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      width: width,
      child: row,
    );
    final mouseRegion = MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: handleEnter,
      onExit: handleExit,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : handleTap,
      child: mouseRegion,
    );
  }

  void handleTap() {
    DesktopContextMenuManager.instance.dismiss();
    widget.onTap?.call();
  }

  void handleEnter(PointerEnterEvent event) {
    setState(() => hover = true);
  }

  void handleExit(PointerExitEvent event) {
    setState(() => hover = false);
  }
}

/// 设置行里的模型下拉：显示 `模型名 · provider`，点开 [DesktopSettingModelMenu]。
class DesktopSettingModelSelect extends StatelessWidget {
  final int? modelId;
  final void Function(int)? onChanged;

  /// 允许清空为「No model」（传 0）。
  final bool clearable;
  const DesktopSettingModelSelect({
    super.key,
    this.modelId,
    this.onChanged,
    this.clearable = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = _label();
    return AthenaSettingsSelect(
      label: label ?? 'No model',
      placeholder: label == null,
      onTap: (anchor) => DesktopSettingModelMenu.show(
        context,
        anchor,
        selectedId: modelId,
        onSelected: (model) => onChanged?.call(model.id!),
        onCleared: clearable ? () => onChanged?.call(0) : null,
      ),
    );
  }

  String? _label() {
    if (modelId == null || modelId == 0) return null;
    final groups = GetIt.instance<ModelViewModel>().groupedEnabledModels.value;
    for (final entry in groups.entries) {
      for (final model in entry.value) {
        if (model.id == modelId) return '${model.name} · ${entry.key}';
      }
    }
    // 模型存在但它的 provider 已停用：从全量列表里找名字
    final all = GetIt.instance<ModelViewModel>().models.value;
    final model = all.where((m) => m.id == modelId).firstOrNull;
    if (model == null) return null;
    return '${model.name} · disabled provider';
  }
}
