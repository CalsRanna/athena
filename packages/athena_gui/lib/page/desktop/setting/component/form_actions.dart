import 'package:athena_gui/widget/dialog.dart';
import 'package:flutter/material.dart';

/// 表单对话框底部的 Cancel / Confirm。
class DesktopSettingFormActions extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  const DesktopSettingFormActions({
    super.key,
    this.onCancel,
    this.onConfirm,
    this.confirmLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    return AthenaDialogActions(
      onCancel: onCancel,
      onConfirm: onConfirm,
      confirmLabel: confirmLabel,
    );
  }
}
