import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/page/mobile/component/empty_state.dart';
import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/bottom_sheet_tile.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/page/mobile/component/grid_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

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
    return SignalBuilder(
      builder: (context) {
        final colors = context.athenaColors;
        final skills = viewModel.skills.value;
        return AthenaScaffold(
          appBar: const AthenaAppBar(title: Text('Skills')),
          body: Stack(
            children: [
              _buildData(context, skills),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => navigateFormPage(context, null),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceButtonSecondary,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(AthenaRadius.control),
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                    margin: EdgeInsets.only(
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceMobile,
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(
                              AthenaRadius.inline,
                            ),
                          ),
                          height: 24,
                          width: 24,
                          child: Icon(
                            LucideIcons.plus,
                            // 24 圆角容器内的小符号，按容器比例取 12，不套用三档映射
                            size: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add a skill',
                          style: AthenaTextStyle.section.copyWith(
                            color: colors.textPrimary,
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
      },
    );
  }

  Widget _buildData(BuildContext context, List<Skill> skills) {
    if (skills.isEmpty) {
      return const MobileEmptyState(
        icon: LucideIcons.bookOpen,
        title: 'No skills yet',
        hint:
            'Skills are reusable instructions the agent can load when a task '
            'matches. Add one with the button below.',
      );
    }
    final user = skills.where((skill) => !skill.isBuiltin).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final builtin = skills.where((skill) => skill.isBuiltin).toList();
    return CustomScrollView(
      slivers: [
        if (user.isNotEmpty) ...[
          _sectionTitle(context, 'Skills'),
          _grid(context, user),
        ],
        if (builtin.isNotEmpty) ...[
          _sectionTitle(context, 'Built-in'),
          _grid(context, builtin),
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final colors = context.athenaColors;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(
          title,
          style: AthenaTextStyle.title.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<Skill> skills) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];
          return MobileGridTile(
            title: skill.name,
            subtitle: skill.description,
            trailing: skill.isBuiltin
                ? const Icon(LucideIcons.lockKeyhole)
                : null,
            onTap: () => navigateDetailPage(context, skill),
            onLongPress: () => openBottomSheet(context, skill),
          );
        },
      ),
    );
  }

  void navigateFormPage(BuildContext context, Skill? skill) {
    MobileSkillFormRoute(skill: skill).push<void>(context);
  }

  void navigateDetailPage(BuildContext context, Skill skill) {
    MobileSkillDetailRoute(skill: skill).push<void>(context);
  }

  void openBottomSheet(BuildContext context, Skill skill) {
    HapticFeedback.heavyImpact();
    if (skill.isBuiltin) return;
    final editTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.pencilLine),
      title: 'Edit',
      onTap: () {
        AthenaDialog.dismiss();
        navigateFormPage(context, skill);
      },
    );
    final deleteTile = AthenaBottomSheetTile(
      leading: const Icon(LucideIcons.trash2),
      title: 'Delete',
      onTap: () async {
        AthenaDialog.dismiss();
        final result = await AthenaDialog.confirm('Delete this skill?');
        if (result != true) return;
        await viewModel.deleteSkill(skill);
      },
    );
    final children = [editTile, deleteTile];
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: column,
    );
    AthenaDialog.show(SafeArea(child: padding));
  }
}
