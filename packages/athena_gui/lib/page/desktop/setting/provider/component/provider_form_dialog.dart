import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/form_actions.dart';
import 'package:athena_gui/page/desktop/setting/component/form_field.dart';
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
    final children = [
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
      final copiedProvider = widget.provider!.copyWith(name: name);
      await viewModel.updateProvider(copiedProvider);
      if (mounted) widget.onStored?.call(copiedProvider);
    } else {
      final newProvider = ProviderEntity(
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
