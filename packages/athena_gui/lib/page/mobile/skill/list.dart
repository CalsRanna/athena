import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 技能管理列表：网格卡片 + 底部浮动新建按钮；长按编辑/删除，
/// 内置 Skill 显示锁图标且不可编辑删除。
@RoutePage()
class MobileSkillListPage extends StatefulWidget {
  const MobileSkillListPage({super.key});

  @override
  State<MobileSkillListPage> createState() => _MobileSkillListPageState();
}

class _MobileSkillListPageState extends State<MobileSkillListPage> {
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
      var skills = viewModel.skills.value;
      return AthenaScaffold(
        appBar: AthenaAppBar(title: const Text('Skills')),
        body: Stack(
          children: [
            _buildData(context, skills),
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => navigateFormPage(context, null),
                child: Container(
                  decoration: ShapeDecoration(
                    color: colors.surfaceDeep,
                    shape: const StadiumBorder(),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        height: 24,
                        width: 24,
                        child: Icon(
                          HugeIcons.strokeRoundedAdd01,
                          size: 12,
                          color: colors.iconOnRaised,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add a skill',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildData(BuildContext context, List<Skill> skills) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    if (skills.isEmpty) {
      var textStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );
      return Center(child: Text('No skills yet', style: textStyle));
    }
    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      itemCount: skills.length,
      itemBuilder: (context, index) {
        var skill = skills[index];
        return _Tile(
          skill: skill,
          onTap: () => navigateDetailPage(context, skill),
          onLongPress: () => openBottomSheet(context, skill),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void navigateFormPage(BuildContext context, Skill? skill) {
    MobileSkillFormRoute(skill: skill).push(context);
  }

  void navigateDetailPage(BuildContext context, Skill skill) {
    MobileSkillDetailRoute(skill: skill).push(context);
  }

  void openBottomSheet(BuildContext context, Skill skill) {
    HapticFeedback.heavyImpact();
    if (skill.isBuiltin) return;
    var editTile = AthenaBottomSheetTile(
      leading: const Icon(HugeIcons.strokeRoundedPencilEdit02),
      title: 'Edit',
      onTap: () {
        AthenaDialog.dismiss();
        navigateFormPage(context, skill);
      },
    );
    var deleteTile = AthenaBottomSheetTile(
      leading: const Icon(HugeIcons.strokeRoundedDelete02),
      title: 'Delete',
      onTap: () async {
        AthenaDialog.dismiss();
        var result = await AthenaDialog.confirm('Delete this skill?');
        if (result != true) return;
        await viewModel.deleteSkill(skill);
      },
    );
    var children = [editTile, deleteTile];
    var column = Column(mainAxisSize: MainAxisSize.min, children: children);
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }
}

class _Tile extends StatelessWidget {
  final Skill skill;
  final void Function()? onTap;
  final void Function()? onLongPress;

  const _Tile({required this.skill, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var nameTextStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    var descriptionTextStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 12,
    );
    var nameChildren = [
      Expanded(child: Text(skill.name, style: nameTextStyle)),
      if (skill.isBuiltin)
        Icon(
          HugeIcons.strokeRoundedCircleLock01,
          size: 12,
          color: colors.textOnRaised,
        ),
    ];
    var children = [
      Row(children: nameChildren),
      Text(skill.description, style: descriptionTextStyle),
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: colors.surfaceRaised,
    );
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(12),
      child: column,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: container,
    );
  }
}
