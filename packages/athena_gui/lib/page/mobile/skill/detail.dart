import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Skill 详情页：展示 SKILL.md 内容（描述/允许工具/正文/路径），
/// 提供编辑与删除入口；内置 Skill 只读。
@RoutePage()
class MobileSkillDetailPage extends StatefulWidget {
  final Skill skill;
  const MobileSkillDetailPage({super.key, required this.skill});

  @override
  State<MobileSkillDetailPage> createState() => _MobileSkillDetailPageState();
}

class _MobileSkillDetailPageState extends State<MobileSkillDetailPage> {
  late final viewModel = GetIt.instance<SkillViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var skill = viewModel.skills.value
          .where((s) => s.name == widget.skill.name)
          .firstOrNull;
      skill ??= widget.skill;
      var nameRowChildren = [
        Expanded(
          child: Text(
            skill.name,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (skill.isBuiltin)
          Icon(
            HugeIcons.strokeRoundedCircleLock01,
            size: 16,
            color: colors.iconSecondary,
          ),
      ];
      var children = [
        Row(children: nameRowChildren),
        const SizedBox(height: 8),
        Text(
          skill.description,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
        if (skill.allowedTools != null && skill.allowedTools!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(context, 'Allowed tools'),
          const SizedBox(height: 8),
          Text(
            skill.allowedTools!,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        _label(context, 'Instructions'),
        const SizedBox(height: 8),
        _buildBody(context, skill.body),
        const SizedBox(height: 16),
        Text(
          skill.sourcePath,
          style: TextStyle(color: colors.textWeak, fontSize: 12),
        ),
        const SizedBox(height: 24),
        if (!skill.isBuiltin) _buildButtons(context, skill),
        SafeArea(top: false, child: const SizedBox()),
      ];
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Skill')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: children,
        ),
      );
    });
  }

  Widget _label(BuildContext context, String text) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Text(
      text,
      style: TextStyle(
        color: colors.textWeak,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBody(BuildContext context, String body) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        body,
        style: GoogleFonts.firaCode(
          fontSize: 12,
          height: 1.5,
          color: colors.textOnRaised,
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, Skill skill) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(
        child: AthenaPrimaryButton(
          onTap: () => navigateFormPage(context, skill),
          child: Center(child: Text('Edit', style: textStyle)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: AthenaTextButton(
          text: 'Delete',
          onTap: () => destroySkill(context, skill),
        ),
      ),
    ];
    return Row(children: children);
  }

  void navigateFormPage(BuildContext context, Skill skill) {
    MobileSkillFormRoute(skill: skill).push(context);
  }

  Future<void> destroySkill(BuildContext context, Skill skill) async {
    var result = await AthenaDialog.confirm('Delete this skill?');
    if (result != true) return;
    var removed = await viewModel.deleteSkill(skill);
    if (!context.mounted) return;
    if (!removed) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to delete skill');
      return;
    }
    AutoRouter.of(context).maybePop();
  }
}
