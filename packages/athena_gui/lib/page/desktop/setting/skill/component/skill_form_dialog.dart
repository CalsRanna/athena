import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class DesktopSkillFormDialog extends StatefulWidget {
  final Skill? skill;
  final void Function()? onStored;

  const DesktopSkillFormDialog({super.key, this.skill, this.onStored});

  @override
  State<DesktopSkillFormDialog> createState() => _DesktopSkillFormDialogState();
}

class _DesktopSkillFormDialogState extends State<DesktopSkillFormDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  late final viewModel = GetIt.instance<SkillViewModel>();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.skill?.name ?? '';
    descriptionController.text = widget.skill?.description ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var nameChildren = [
      SizedBox(width: 120, child: const AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(
        child: AthenaInput(
          controller: nameController,
          enabled: widget.skill == null,
          placeholder: 'kebab-case-name',
        ),
      ),
    ];
    var descriptionChildren = [
      SizedBox(
        width: 120,
        child: const AthenaFormTileLabel(title: 'Description'),
      ),
      const SizedBox(width: 12),
      Expanded(child: AthenaInput(controller: descriptionController)),
    ];
    var children = [
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: descriptionChildren),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    return AthenaDesktopDialog(
      title: widget.skill == null ? 'Add Skill' : 'Edit Skill',
      onClose: cancelDialog,
      child: SingleChildScrollView(child: column),
    );
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeSkill() async {
    final skill = widget.skill;
    final ok = skill == null
        ? await viewModel.createSkill(
            name: nameController.text,
            description: descriptionController.text,
            body: '',
          )
        : await viewModel.updateSkill(
            skill,
            description: descriptionController.text,
            body: skill.body,
          );
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to save skill');
      return;
    }
    widget.onStored?.call();
    AthenaDialog.dismiss();
  }

  Widget _buildButtons() {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var cancelButton = AthenaSecondaryButton(
      onTap: cancelDialog,
      child: const Padding(padding: edgeInsets, child: Text('Cancel')),
    );
    var storeButton = AthenaPrimaryButton(
      onTap: storeSkill,
      child: const Padding(padding: edgeInsets, child: Text('Store')),
    );
    var children = [cancelButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }
}
