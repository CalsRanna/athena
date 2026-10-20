import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DesktopImageSelector extends StatelessWidget {
  final bool compact;
  final String? label;
  final void Function(List<String>)? onSelected;
  const DesktopImageSelector({
    super.key,
    this.compact = false,
    this.label,
    this.onSelected,
  });

  const DesktopImageSelector.compact({
    super.key,
    this.label = 'Images',
    this.onSelected,
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (compact) return _buildCompactButton(context);
    // 附件入口是一个裸加号，不是图片字形。图标 16 + 上下左右各 6 = 28 的
    // hover 方盒，与同一行文字控件的 hover 底同高；不加内边距的话填充会紧贴
    // 字形，看起来比旁边的按钮小一圈。
    return AthenaGhostButton(
      onTap: selectImages,
      padding: const EdgeInsets.all(6),
      child: Icon(
        LucideIcons.plus,
        color: colors.textPrimary,
        size: AthenaIcon.regularSize,
      ),
    );
  }

  Widget _buildCompactButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.image,
          color: colors.textPrimary,
          size: AthenaIcon.inlineSize,
        ),
        const SizedBox(width: 8),
        Text(label ?? 'Images'),
      ],
    );
    return AthenaSecondaryButton.small(onTap: selectImages, child: row);
  }

  Future<void> selectImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    final List<String> images = [];
    for (var file in result.files) {
      if (file.path == null) continue;
      images.add(file.path!);
    }
    onSelected?.call(images);
  }
}
