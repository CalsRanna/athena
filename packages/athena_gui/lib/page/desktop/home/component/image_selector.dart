import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedImage01,
      color: colors.textPrimary,
      size: 24,
    );
    return GestureDetector(
      onTap: selectImages,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
  }

  Widget _buildCompactButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HugeIcons.strokeRoundedImage01,
          color: colors.textPrimary,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(label ?? 'Images'),
      ],
    );
    return AthenaSecondaryButton.small(onTap: selectImages, child: row);
  }

  Future<void> selectImages() async {
    var result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    List<String> images = [];
    for (var file in result.files) {
      if (file.path == null) continue;
      images.add(file.path!);
    }
    onSelected?.call(images);
  }
}
