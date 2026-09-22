import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 新建 / 重命名 provider 的对话框：只问名字，密钥与地址在详情页填。
///
/// 新建成功后通过 [onStored] 把带 id 的实体交回列表页，列表页直接钻进去。
class DesktopProviderFormDialog extends StatefulWidget {
  final ProviderEntity? provider;
  final void Function(ProviderEntity provider)? onStored;
  const DesktopProviderFormDialog({super.key, this.provider, this.onStored});

  @override
  State<DesktopProviderFormDialog> createState() =>
      _DesktopProviderFormDialogState();
}

class _DesktopProviderFormDialogState extends State<DesktopProviderFormDialog> {
  final nameController = TextEditingController();
  String? error;

  late final viewModel = GetIt.instance<ProviderViewModel>();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.provider?.name ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopSettingFormField(
        label: 'Name',
        error: error,
        child: AthenaSettingsTextField(
          controller: nameController,
          autofocus: true,
          placeholder: 'e.g. Local Ollama',
          onSubmitted: (_) => storeProvider(),
        ),
      ),
      const SizedBox(height: AthenaSpace.xxl),
      DesktopSettingFormActions(
        onCancel: cancelDialog,
        onConfirm: storeProvider,
        confirmLabel: widget.provider == null ? 'Add' : 'Save',
      ),
    ];
    return AthenaDesktopDialog(
      title: widget.provider == null ? 'Add provider' : 'Rename provider',
      onClose: cancelDialog,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeProvider() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Give the provider a name.');
      return;
    }
    if (widget.provider != null) {
      var copiedProvider = widget.provider!.copyWith(name: name);
      await viewModel.updateProvider(copiedProvider);
      if (mounted) widget.onStored?.call(copiedProvider);
    } else {
      var newProvider = ProviderEntity(
        id: 0,
        enabled: true,
        name: name,
        baseUrl: '',
        apiKey: '',
        createdAt: DateTime.now(),
      );
      final created = await viewModel.storeProvider(newProvider);
      if (created != null && mounted) widget.onStored?.call(created);
    }
    if (mounted) AthenaDialog.dismiss();
  }
}

/// 设置表单对话框里的一项：标签在上、控件在下（Claude 的表单是纵向的，
/// 不是「左标签右输入」的两列）。
class DesktopSettingFormField extends StatelessWidget {
  final String label;
  final String? hint;
  final String? error;
  final Widget child;
  const DesktopSettingFormField({
    super.key,
    required this.label,
    this.hint,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var labelStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: AthenaSettings.rowFontSize,
      fontWeight: AthenaSettings.rowLabelWeight,
      height: 1.4,
    );
    var hintStyle = AthenaTextStyle.caption.copyWith(
      color: colors.textWeak,
      height: 1.4,
    );
    var errorStyle = AthenaTextStyle.caption.copyWith(
      color: colors.dangerText,
      height: 1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: errorStyle),
        ] else if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: hintStyle),
        ],
      ],
    );
  }
}

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
    var children = [
      AthenaSecondaryButton(onTap: onCancel, child: const Text('Cancel')),
      const SizedBox(width: AthenaSpace.sm),
      AthenaPrimaryButton(onTap: onConfirm, child: Text(confirmLabel)),
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }
}
