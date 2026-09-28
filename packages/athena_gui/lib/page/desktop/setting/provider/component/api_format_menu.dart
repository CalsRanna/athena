import 'package:athena_core/entity/api_format.dart';
import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/component/api_format_label.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';

/// 设置行里的 API 格式选择：显示当前格式，自动同步时在前面加 `Auto · `，
/// 点开 [DesktopSettingApiFormatMenu]。
class DesktopSettingApiFormatSelect extends StatelessWidget {
  final ProviderEntity provider;

  /// `auto: true` 表示交还给 models.dev 同步；`auto: false` 时必须给 [format]。
  final void Function({required bool auto, ApiFormat? format}) onSelected;

  const DesktopSettingApiFormatSelect({
    super.key,
    required this.provider,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final name = provider.apiFormat.label;
    return AthenaSettingsSelect(
      label: provider.apiFormatAuto ? 'Auto · $name' : name,
      onTap: (anchor) => DesktopSettingApiFormatMenu.show(
        context,
        anchor,
        provider: provider,
        onSelected: onSelected,
      ),
    );
  }
}

/// API 格式的下拉菜单：锚在 select 下方、与它同宽，当前值行尾打钩。
///
/// 与设置里的模型菜单同一套视觉（`DesktopContextMenu` 面板 + 统一的菜单条目），
/// 首项是「跟随 models.dev」，其余是三种协议。
class DesktopSettingApiFormatMenu extends StatelessWidget {
  final Rect anchor;
  final ProviderEntity provider;
  final void Function({required bool auto, ApiFormat? format}) onSelected;

  const DesktopSettingApiFormatMenu({
    super.key,
    required this.anchor,
    required this.provider,
    required this.onSelected,
  });

  static void show(
    BuildContext context,
    Rect anchor, {
    required ProviderEntity provider,
    required void Function({required bool auto, ApiFormat? format}) onSelected,
  }) {
    DesktopContextMenuManager.instance.show(
      context,
      DesktopSettingApiFormatMenu(
        anchor: anchor,
        provider: provider,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 面板自带 4 内边距，条目宽 = 控件宽 − 8 才能让面板外沿与控件同宽
    final width = anchor.width - 8;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final below = screenHeight - anchor.bottom - 16;
    final upward = below < 200 && anchor.top > below;
    final maxHeight = (upward ? anchor.top - 16 : below).clamp(120.0, 300.0);
    return DesktopContextMenu(
      offset: upward
          ? Offset(anchor.left, anchor.top - 4)
          : Offset(anchor.left, anchor.bottom + 4),
      upward: upward,
      width: width,
      children: [
        DesktopContextMenuList(
          maxHeight: maxHeight,
          children: [
            DesktopContextMenuTile(
              text: 'Auto (models.dev)',
              selected: provider.apiFormatAuto,
              onTap: () => onSelected(auto: true),
            ),
            for (final format in ApiFormat.values)
              DesktopContextMenuTile(
                text: format.label,
                selected:
                    !provider.apiFormatAuto && provider.apiFormat == format,
                onTap: () => onSelected(auto: false, format: format),
              ),
          ],
        ),
      ],
    );
  }
}
