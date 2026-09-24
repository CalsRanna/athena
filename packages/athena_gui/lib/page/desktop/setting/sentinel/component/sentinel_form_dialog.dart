import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 新建 Sentinel 的对话框：只问名字，其余在编辑页填。
///
/// 新建成功后通过 [onStored] 把带 id 的实体交回列表页，列表页直接打开编辑。
class DesktopSentinelFormDialog extends StatefulWidget {
  final void Function(SentinelEntity sentinel)? onStored;
  const DesktopSentinelFormDialog({super.key, this.onStored});

  @override
  State<DesktopSentinelFormDialog> createState() =>
      _DesktopSentinelFormDialogState();
}

class _DesktopSentinelFormDialogState extends State<DesktopSentinelFormDialog> {
  final nameController = TextEditingController();
  String? error;

  late final viewModel = GetIt.instance<SentinelViewModel>();

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
        hint: 'You can write the system prompt on the next screen.',
        error: error,
        child: AthenaSettingsTextField(
          controller: nameController,
          autofocus: true,
          placeholder: 'e.g. Code reviewer',
          onSubmitted: (_) => storeSentinel(),
        ),
      ),
      const SizedBox(height: AthenaSpace.xxl),
      DesktopSettingFormActions(
        onCancel: cancelDialog,
        onConfirm: storeSentinel,
        confirmLabel: 'Create',
      ),
    ];
    return AthenaDesktopDialog(
      title: 'New Sentinel',
      onClose: cancelDialog,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeSentinel() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Give the Sentinel a name.');
      return;
    }
    var newSentinel = SentinelEntity(
      id: 0,
      name: name,
      prompt: '',
      description: '',
      tags: '',
    );
    final created = await viewModel.createSentinel(newSentinel);
    if (!mounted) return;
    if (created == null) {
      setState(() => error = viewModel.error.value ?? 'Failed to create');
      return;
    }
    AthenaDialog.dismiss();
    widget.onStored?.call(created);
  }
}
