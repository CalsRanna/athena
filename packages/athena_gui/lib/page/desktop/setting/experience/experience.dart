import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/page/desktop/setting/experience/component/experience_context_menu.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端经验管理：左栏列表（含归档开关）+ 右侧只读详情。
///
/// 经验内容由 Agent 进化产出，不支持手工新建/编辑；
/// 归档/恢复与删除通过列表项右键菜单完成。
@RoutePage()
class DesktopSettingExperiencePage extends StatefulWidget {
  const DesktopSettingExperiencePage({super.key});

  @override
  State<DesktopSettingExperiencePage> createState() =>
      _DesktopSettingExperiencePageState();
}

class _DesktopSettingExperiencePageState
    extends State<DesktopSettingExperiencePage> {
  int index = 0;

  late final viewModel = GetIt.instance<ExperienceViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildExperienceListView(),
      Expanded(child: _buildExperienceView()),
    ];
    return Row(children: children);
  }

  void changeExperience(int index) {
    setState(() {
      this.index = index;
    });
  }

  Future<void> destroyExperience(ExperienceEntity experience) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this experience?',
    );
    if (result != true) return;
    var experiences = viewModel.experiences.value;
    final deletedIndex = experiences.indexWhere((e) => e.id == experience.id);
    final selectedId = index < experiences.length
        ? experiences[index].id
        : null;
    await viewModel.deleteExperience(experience);
    final remaining = viewModel.experiences.value;
    if (remaining.any((e) => e.id == experience.id)) return;
    if (remaining.isEmpty) {
      setState(() => index = 0);
      return;
    }
    var nextIndex = remaining.indexWhere((e) => e.id == selectedId);
    if (selectedId == experience.id || nextIndex < 0) {
      nextIndex = deletedIndex > 0 ? deletedIndex - 1 : 0;
    }
    changeExperience(nextIndex);
  }

  Future<void> toggleStatus(ExperienceEntity experience) async {
    var isArchived = experience.status == ExperienceEntity.statusArchived;
    var ok = isArchived
        ? await viewModel.restoreExperience(experience)
        : await viewModel.archiveExperience(experience);
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.warning(viewModel.error.value ?? 'Operation failed');
      return;
    }
    var remaining = viewModel.experiences.value;
    if (remaining.isEmpty) {
      setState(() => index = 0);
      return;
    }
    if (index >= remaining.length) {
      changeExperience(remaining.length - 1);
    }
  }

  void showExperienceContextMenu(
    TapUpDetails details,
    ExperienceEntity experience,
  ) {
    var isArchived = experience.status == ExperienceEntity.statusArchived;
    var contextMenu = DesktopExperienceContextMenu(
      offset: details.globalPosition - const Offset(240, 50),
      isArchived: isArchived,
      onToggledStatus: () => toggleStatus(experience),
      onDestroyed: () => destroyExperience(experience),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  Widget _buildExperienceListView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var experiences = viewModel.experiences.value;
      var borderSide = BorderSide(
        color: colors.borderFaint.withValues(alpha: 0.2),
      );
      Widget child = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) =>
            _buildExperienceTile(context, experiences, index),
        itemCount: experiences.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      if (experiences.isEmpty) {
        var textStyle = TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        );
        child = Center(child: Text('No Experiences', style: textStyle));
      }
      return Container(
        decoration: BoxDecoration(border: Border(right: borderSide)),
        width: 240,
        child: child,
      );
    });
  }

  Widget _buildExperienceTile(
    BuildContext context,
    List<ExperienceEntity> experiences,
    int index,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var experience = experiences[index];
    var isArchived = experience.status == ExperienceEntity.statusArchived;
    var trailingColor = this.index == index
        ? colors.textSelected
        : colors.iconSecondary;
    var trailing = isArchived
        ? Icon(
            HugeIcons.strokeRoundedArchive,
            size: 10,
            color: trailingColor,
          )
        : null;
    return DesktopMenuTile(
      active: this.index == index,
      label: experience.lesson,
      trailing: trailing,
      onSecondaryTap: (details) =>
          showExperienceContextMenu(details, experience),
      onTap: () => changeExperience(index),
    );
  }

  Widget _buildExperienceView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var experiences = viewModel.experiences.value;
      if (experiences.isEmpty) return const SizedBox();
      var experience = experiences[index];
      var isArchived = experience.status == ExperienceEntity.statusArchived;
      var sectionTextStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 14,
        height: 1.5,
      );
      var labelTextStyle = TextStyle(color: colors.textWeak, fontSize: 12);
      var valueTextStyle = TextStyle(color: colors.textPrimary, fontSize: 13);

      Widget metaRow(String label, String value) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(label, style: labelTextStyle),
              ),
              Expanded(child: Text(value, style: valueTextStyle)),
            ],
          ),
        );
      }

      var children = [
        Text(
          viewModel.ownerLabel(experience),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        metaRow('Scope', experience.scope),
        metaRow('Source', experience.source),
        metaRow('Status', isArchived ? 'Archived' : 'Active'),
        metaRow('Created', _formatDate(experience.createdAt)),
        if (experience.updatedAt != null)
          metaRow('Updated', _formatDate(experience.updatedAt!)),
        const SizedBox(height: 16),
        Text('Lesson', style: labelTextStyle),
        const SizedBox(height: 8),
        Text(experience.lesson, style: sectionTextStyle),
        if (experience.context.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Context', style: labelTextStyle),
          const SizedBox(height: 8),
          Text(experience.context, style: sectionTextStyle),
        ],
        if (experience.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Tags', style: labelTextStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in experience.tags) AthenaTag.small(text: tag),
            ],
          ),
        ],
        const SizedBox(height: 32),
        SafeArea(top: false, child: const SizedBox()),
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        children: children,
      );
    });
  }
}

String _formatDate(DateTime dt) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
}
