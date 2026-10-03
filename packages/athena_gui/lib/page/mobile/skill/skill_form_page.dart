import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Skill 新建/编辑表单。编辑时名称不可修改（Skill 名即目录名）。
@RoutePage()
class MobileSkillFormPage extends StatefulWidget {
  final Skill? skill;
  const MobileSkillFormPage({super.key, this.skill});

  @override
  State<MobileSkillFormPage> createState() => _MobileSkillFormPageState();
}

class _MobileSkillFormPageState extends State<MobileSkillFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final bodyController = TextEditingController();

  late final viewModel = GetIt.instance<SkillViewModel>();

  bool get isEdit => widget.skill != null;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.skill?.name ?? '';
    descriptionController.text = widget.skill?.description ?? '';
    bodyController.text = widget.skill?.body ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listChildren = [
      if (!isEdit) ...[
        AthenaFormField(
          label: 'Name',
          control: AthenaInput(
            controller: nameController,
            placeholder: 'kebab-case-name',
          ),
          description:
              'Used as the skill directory name; cannot be changed later',
        ),
        const SizedBox(height: 16),
      ],
      AthenaFormField(
        label: 'Description',
        control: AthenaInput(
          controller: descriptionController,
          maxLines: 4,
          minLines: 4,
        ),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Instructions',
        control: AthenaInput(
          controller: bodyController,
          maxLines: 16,
          minLines: 16,
        ),
      ),
      const SizedBox(height: 32),
      const SafeArea(top: false, child: SizedBox()),
    ];
    final listView = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listChildren,
    );
    final column = Column(
      children: [
        Expanded(child: listView),
        _buildStoreButton(context),
      ],
    );
    return AthenaScaffold(
      appBar: AthenaAppBar(
        title: Text(isEdit ? widget.skill!.name : 'New Skill'),
      ),
      body: SafeArea(top: false, child: column),
    );
  }

  Widget _buildStoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AthenaPrimaryButton(
        onTap: storeSkill,
        child: const Center(child: Text('Store')),
      ),
    );
  }

  Future<void> storeSkill() async {
    bool ok;
    if (isEdit) {
      ok = await viewModel.updateSkill(
        widget.skill!,
        description: descriptionController.text,
        body: bodyController.text,
      );
    } else {
      ok = await viewModel.createSkill(
        name: nameController.text,
        description: descriptionController.text,
        body: bodyController.text,
      );
    }
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to save skill');
      return;
    }
    AutoRouter.of(context).maybePop();
  }
}
