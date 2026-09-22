import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/page/desktop/setting/provider/component/provider_form_dialog.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// 新建技能的对话框：名字（目录名）+ 一句描述，正文在编辑页写。
///
/// 成功后通过 [onStored] 把技能名交回列表页，列表页直接打开编辑。
class DesktopSkillFormDialog extends StatefulWidget {
  final void Function(String name)? onStored;
  const DesktopSkillFormDialog({super.key, this.onStored});

  @override
  State<DesktopSkillFormDialog> createState() => _DesktopSkillFormDialogState();
}

class _DesktopSkillFormDialogState extends State<DesktopSkillFormDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  String? nameError;
  String? descriptionError;

  late final viewModel = GetIt.instance<SkillViewModel>();

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopSettingFormField(
        label: 'Name',
        hint: 'Becomes the folder name. Lowercase words joined by dashes.',
        error: nameError,
        child: AthenaSettingsTextField(
          controller: nameController,
          autofocus: true,
          mono: true,
          placeholder: 'kebab-case-name',
        ),
      ),
      const SizedBox(height: AthenaSpace.lg),
      DesktopSettingFormField(
        label: 'Description',
        hint: 'One sentence the agent reads to decide when to use it.',
        error: descriptionError,
        child: AthenaSettingsTextField(
          controller: descriptionController,
          placeholder: 'Use when…',
          onSubmitted: (_) => storeSkill(),
        ),
      ),
      const SizedBox(height: AthenaSpace.xxl),
      DesktopSettingFormActions(
        onCancel: cancelDialog,
        onConfirm: storeSkill,
        confirmLabel: 'Create',
      ),
    ];
    return AthenaDesktopDialog(
      title: 'New skill',
      onClose: cancelDialog,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeSkill() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    setState(() {
      nameError = !SkillLoader.isValidSkillName(name)
          ? 'Use letters, digits and dashes only.'
          : null;
      descriptionError = description.isEmpty ? 'Description is required.' : null;
    });
    if (nameError != null || descriptionError != null) return;
    final ok = await viewModel.createSkill(
      name: name,
      description: description,
      body: '',
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => nameError = viewModel.error.value ?? 'Failed to create');
      return;
    }
    AthenaDialog.dismiss();
    widget.onStored?.call(name);
  }
}
