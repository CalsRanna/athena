import 'package:athena/util/color_util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class DesktopImageSelector extends StatelessWidget {
  final void Function(List<String>)? onSelected;
  const DesktopImageSelector({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    var hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedImage01,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    return GestureDetector(
      onTap: selectImages,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: hugeIcon),
    );
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
