import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

/// 桌面端新建 Skill：仅收集名称与描述，创建后在右侧编辑区完善正文。
class DesktopSkillFormDialog extends StatefulWidget {
  const DesktopSkillFormDialog({super.key});

  @override
  State<DesktopSkillFormDialog> createState() => _DesktopSkillFormDialogState();
}

class _DesktopSkillFormDialogState extends State<DesktopSkillFormDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  late final viewModel = GetIt.instance<SkillViewModel>();

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: colors.surfaceMobile,
    );
    var titleTextStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var closeButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cancelDialog,
      child: Icon(
        HugeIcons.strokeRoundedCancel01,
        color: colors.textPrimary,
        size: 24,
      ),
    );
    var titleChildren = [
      Text('Add Skill', style: titleTextStyle),
      const Spacer(),
      closeButton,
    ];
    var nameChildren = [
      SizedBox(width: 120, child: const AthenaFormTileLabel(title: 'Name')),
      const SizedBox(width: 12),
      Expanded(
        child: AthenaInput(
          controller: nameController,
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
      Row(children: titleChildren),
      const SizedBox(height: 24),
      Row(children: nameChildren),
      const SizedBox(height: 12),
      Row(children: descriptionChildren),
      const SizedBox(height: 12),
      _buildButtons(),
    ];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(32),
      width: 520,
      child: column,
    );
    return Dialog(backgroundColor: Colors.transparent, child: container);
  }

  void cancelDialog() {
    AthenaDialog.dismiss();
  }

  Future<void> storeSkill() async {
    var ok = await viewModel.createSkill(
      name: nameController.text,
      description: descriptionController.text,
      body: '',
    );
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to create skill');
      return;
    }
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
