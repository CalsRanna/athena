import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/page/desktop/setting/skill/component/skill_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/skill/component/skill_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端技能管理：左栏列表（右键删除，内置锁定）+ 右侧编辑区。
@RoutePage()
class DesktopSettingSkillPage extends StatefulWidget {
  const DesktopSettingSkillPage({super.key});

  @override
  State<DesktopSettingSkillPage> createState() =>
      _DesktopSettingSkillPageState();
}

class _DesktopSettingSkillPageState extends State<DesktopSettingSkillPage> {
  int index = 0;
  final _selection = DesktopListSelection<String>();
  final descriptionController = TextEditingController();
  final bodyController = TextEditingController();

  late final viewModel = GetIt.instance<SkillViewModel>();

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _initState() async {
    await viewModel.load();
    var skills = viewModel.skills.value;
    if (skills.isEmpty) return;
    _fillControllers(skills[index]);
    setState(() {});
  }

  void _fillControllers(Skill skill) {
    descriptionController.text = skill.description;
    bodyController.text = skill.body;
  }

  @override
  Widget build(BuildContext context) {
    var children = [_buildSkillListView(), Expanded(child: _buildSkillView())];
    return Row(children: children);
  }

  Future<void> changeSkill(int index) async {
    setState(() {
      this.index = index;
    });
    var skills = viewModel.skills.value;
    if (skills.isEmpty) return;
    _fillControllers(skills[index]);
  }

  void _handleSkillTap(int tappedIndex) {
    final skills = viewModel.skills.value;
    final skill = skills[tappedIndex];
    final activate = _selection.handleTap(
      skill.name,
      ids: skills
          .where((item) => !item.isBuiltin)
          .map((item) => item.name)
          .toList(),
      activeId: skills[index].name,
    );
    if (activate) {
      changeSkill(tappedIndex);
    } else {
      setState(() {});
    }
  }

  Future<void> destroySkills(List<Skill> targets) async {
    final deletable = targets.where((item) => !item.isBuiltin).toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Do you want to delete this skill?'
          : 'Do you want to delete ${deletable.length} skills?',
    );
    if (confirmed == true) {
      for (final skill in deletable) {
        final before = viewModel.skills.value;
        final deletedIndex = before.indexWhere(
          (item) => item.name == skill.name,
        );
        final activeId = index < before.length ? before[index].name : null;
        await viewModel.deleteSkill(skill);
        final remaining = viewModel.skills.value;
        if (remaining.any((item) => item.name == skill.name)) {
          if (mounted) {
            AthenaDialog.error(
              viewModel.error.value ?? 'Failed to delete skill',
            );
          }
          break;
        }
        if (!mounted) continue;
        if (remaining.isEmpty) {
          setState(() => index = 0);
          continue;
        }
        var nextIndex = remaining.indexWhere((item) => item.name == activeId);
        if (nextIndex < 0) {
          nextIndex = (deletedIndex - 1).clamp(0, remaining.length - 1);
        }
        await changeSkill(nextIndex);
      }
    }
    if (mounted) setState(_selection.clear);
  }

  void storeSkill() async {
    var skills = viewModel.skills.value;
    if (skills.isEmpty) return;
    var skill = skills[index];
    if (skill.isBuiltin) return;
    var ok = await viewModel.updateSkill(
      skill,
      description: descriptionController.text,
      body: bodyController.text,
    );
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to save skill');
      return;
    }
    AthenaDialog.success('Skill updated');
  }

  void showSkillContextMenu(TapUpDetails details, Skill skill) {
    if (skill.isBuiltin) return;
    final selected = viewModel.skills.value
        .where((item) => _selection.selectedIds.contains(item.name))
        .toList();
    final multiSelect = selected.length > 1;
    var contextMenu = DesktopSkillContextMenu(
      multiSelect: multiSelect,
      offset: details.globalPosition - const Offset(240, 50),
      onEdited: () => openSkillFormDialog(skill),
      onDestroyed: () => destroySkills(multiSelect ? selected : [skill]),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void openSkillFormDialog(Skill skill) {
    AthenaDialog.show(
      DesktopSkillFormDialog(
        skill: skill,
        onStored: () {
          if (!mounted) return;
          final savedIndex = viewModel.skills.value.indexWhere(
            (item) => item.name == skill.name,
          );
          if (savedIndex < 0) return;
          _selection.clear();
          changeSkill(savedIndex);
        },
      ),
    );
  }

  Widget _buildSkillListView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var skills = viewModel.skills.value;
      var borderSide = BorderSide(
        color: colors.borderFaint.withValues(alpha: 0.2),
      );
      Widget child = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) =>
            _buildSkillTile(context, skills, index),
        itemCount: skills.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      if (skills.isEmpty) {
        var textStyle = TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        );
        child = Center(child: Text('No Skills', style: textStyle));
      }
      return Container(
        decoration: BoxDecoration(border: Border(right: borderSide)),
        width: 240,
        child: child,
      );
    });
  }

  Widget _buildSkillTile(BuildContext context, List<Skill> skills, int index) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var skill = skills[index];
    final selected =
        this.index == index || _selection.selectedIds.contains(skill.name);
    var trailingColor = selected ? colors.textSelected : colors.iconSecondary;
    var trailing = skill.isBuiltin
        ? Icon(
            HugeIcons.strokeRoundedCircleLock01,
            size: 10,
            color: trailingColor,
          )
        : null;
    return DesktopMenuTile(
      active: selected,
      label: skill.name,
      trailing: trailing,
      onSecondaryTap: (details) => showSkillContextMenu(details, skill),
      onTap: () => _handleSkillTap(index),
    );
  }

  Widget _buildSkillView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var skills = viewModel.skills.value;
      if (skills.isEmpty || index >= skills.length) return const SizedBox();
      var skill = skills[index];
      var nameTextStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );
      var isBuiltin = skill.isBuiltin;
      var descriptionInput = AthenaInput(
        controller: descriptionController,
        maxLines: 4,
        minLines: 4,
      );
      var descriptionChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Description')),
        Expanded(child: descriptionInput),
      ];
      var bodyInput = AthenaInput(
        controller: bodyController,
        maxLines: 20,
        minLines: 20,
      );
      const edgeInsets = EdgeInsets.symmetric(vertical: 16);
      var bodyLabel = SizedBox(
        width: 120,
        child: AthenaFormTileLabel(title: 'Instructions'),
      );
      var bodyChildren = [
        Padding(padding: edgeInsets, child: bodyLabel),
        Expanded(child: bodyInput),
      ];
      var listChildren = [
        Row(
          children: [
            Expanded(child: Text(skill.name, style: nameTextStyle)),
            if (isBuiltin)
              Icon(
                HugeIcons.strokeRoundedCircleLock01,
                size: 14,
                color: colors.iconSecondary,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: descriptionChildren),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: bodyChildren,
        ),
        const SizedBox(height: 12),
        if (!isBuiltin) _buildButtons(context),
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        children: listChildren,
      );
    });
  }

  Widget _buildButtons(BuildContext context) {
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    var storeButton = AthenaPrimaryButton(
      onTap: storeSkill,
      child: const Padding(padding: edgeInsets, child: Text('Store')),
    );
    var children = [const Spacer(), storeButton];
    return Row(children: children);
  }
}
