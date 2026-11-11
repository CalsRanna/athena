import 'package:athena_core/entity/provider_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/provider_view_model.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/form_actions.dart';
import 'package:athena_gui/page/desktop/setting/component/form_field.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// 新建与重命名 provider 的对话框内容；两处共用同一条保存路径。
class DesktopProviderNameForm extends StatefulWidget {
  final ProviderEntity? provider;
  final VoidCallback onCancel;
  final ValueChanged<ProviderEntity> onStored;
  const DesktopProviderNameForm({
    super.key,
    this.provider,
    required this.onCancel,
    required this.onStored,
  });

  @override
  State<DesktopProviderNameForm> createState() =>
      _DesktopProviderNameFormState();
}

class _DesktopProviderNameFormState extends State<DesktopProviderNameForm> {
  final nameController = TextEditingController();
  bool saving = false;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopSettingFormField(
          label: 'Name',
          child: AthenaSettingsTextField(
            controller: nameController,
            autofocus: true,
            enabled: !saving,
            placeholder: 'e.g. Local Ollama',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => storeProvider(),
          ),
        ),
        const SizedBox(height: AthenaSpace.xxl),
        DesktopSettingFormActions(
          onCancel: saving ? null : widget.onCancel,
          onConfirm: saving || nameController.text.trim().isEmpty
              ? null
              : storeProvider,
          confirmLabel: widget.provider == null ? 'Add' : 'Save',
        ),
      ],
    );
  }

  Future<void> storeProvider() async {
    final name = nameController.text.trim();
    if (name.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      if (widget.provider != null) {
        final copiedProvider = widget.provider!.copyWith(name: name);
        await viewModel.updateProvider(copiedProvider);
        if (mounted) widget.onStored.call(copiedProvider);
      } else {
        final newProvider = ProviderEntity(
          enabled: true,
          name: name,
          baseUrl: '',
          apiKey: '',
          createdAt: DateTime.now(),
        );
        final created = await viewModel.storeProvider(newProvider);
        if (created != null && mounted) widget.onStored.call(created);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
