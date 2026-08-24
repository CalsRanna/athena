import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/reasoning_effort_dialog.dart';
import 'package:flutter/material.dart';

/// 工具栏上的推理强度入口:文字展示当前档位,点击打开选择对话框。
///
/// 展示的是实时的 [current](由外部 Watch 驱动),不依赖对话框内部状态。
class DesktopReasoningEffortButton extends StatelessWidget {
  final String? current;
  final void Function(String?)? onSelected;

  const DesktopReasoningEffortButton({
    super.key,
    required this.current,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var text = Text(
      reasoningEffortLabel(current),
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
    return GestureDetector(
      onTap: openDialog,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
    );
  }

  void openDialog() {
    var dialog = DesktopReasoningEffortSelectDialog(
      current: current,
      onTap: _select,
    );
    AthenaDialog.show(dialog, barrierDismissible: true);
  }

  void _select(String? value) {
    AthenaDialog.dismiss();
    onSelected?.call(value);
  }
}
