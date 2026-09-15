import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/page/desktop/setting/experience/component/experience_context_menu.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
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
  final _selection = DesktopListSelection<(String, String)>();

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

  void _handleExperienceTap(int tappedIndex) {
    final experiences = viewModel.experiences.value;
    final experience = experiences[tappedIndex];
    final activate = _selection.handleTap(
      (experience.sentinelId, experience.id),
      ids: experiences.map((item) => (item.sentinelId, item.id)).toList(),
      activeId: index < experiences.length
          ? (experiences[index].sentinelId, experiences[index].id)
          : null,
    );
    if (activate) {
      changeExperience(tappedIndex);
    } else {
      setState(() {});
    }
  }

  Future<void> destroyExperiences(List<ExperienceEntity> targets) async {
    final deletable = targets;
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Do you want to delete this experience?'
          : 'Do you want to delete ${deletable.length} experiences?',
    );
    if (confirmed == true) {
      for (final experience in deletable) {
        final before = viewModel.experiences.value;
        final deletedIndex = before.indexWhere(
          (item) =>
              (item.sentinelId, item.id) ==
              (experience.sentinelId, experience.id),
        );
        final activeId = index < before.length
            ? (before[index].sentinelId, before[index].id)
            : null;
        await viewModel.deleteExperience(experience);
        final remaining = viewModel.experiences.value;
        if (remaining.any(
          (item) =>
              (item.sentinelId, item.id) ==
              (experience.sentinelId, experience.id),
        )) {
          if (mounted) {
            AthenaDialog.error(
              viewModel.error.value ?? 'Failed to delete experience',
            );
          }
          break;
        }
        if (!mounted) continue;
        if (remaining.isEmpty) {
          setState(() => index = 0);
          continue;
        }
        var nextIndex = remaining.indexWhere(
          (item) => (item.sentinelId, item.id) == activeId,
        );
        if (nextIndex < 0) {
          nextIndex = (deletedIndex - 1).clamp(0, remaining.length - 1);
        }
        changeExperience(nextIndex);
      }
    }
    if (mounted) setState(_selection.clear);
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

  Future<void> archiveExperiences(List<ExperienceEntity> targets) async {
    for (final experience in targets) {
      if (experience.status == ExperienceEntity.statusArchived) continue;
      final ok = await viewModel.archiveExperience(experience);
      if (!ok) {
        if (mounted) {
          AthenaDialog.warning(viewModel.error.value ?? 'Operation failed');
        }
        break;
      }
    }
    if (mounted) setState(_selection.clear);
  }

  void showExperienceContextMenu(
    TapUpDetails details,
    ExperienceEntity experience,
  ) {
    var isArchived = experience.status == ExperienceEntity.statusArchived;
    final selected = viewModel.experiences.value
        .where(
          (item) => _selection.selectedIds.contains((item.sentinelId, item.id)),
        )
        .toList();
    final multiSelect = selected.length > 1;
    var contextMenu = DesktopExperienceContextMenu(
      multiSelect: multiSelect,
      canArchive: selected.any(
        (item) => item.status != ExperienceEntity.statusArchived,
      ),
      offset: details.globalPosition - const Offset(240, 50),
      isArchived: isArchived,
      onToggledStatus: () =>
          multiSelect ? archiveExperiences(selected) : toggleStatus(experience),
      onDestroyed: () =>
          destroyExperiences(multiSelect ? selected : [experience]),
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
    final selected =
        this.index == index ||
        _selection.selectedIds.contains((experience.sentinelId, experience.id));
    var trailingColor = selected ? colors.textSelected : colors.iconSecondary;
    var trailing = isArchived
        ? Icon(HugeIcons.strokeRoundedArchive, size: 10, color: trailingColor)
        : null;
    return DesktopMenuTile(
      active: selected,
      label: experience.lesson,
      trailing: trailing,
      onSecondaryTap: (details) =>
          showExperienceContextMenu(details, experience),
      onTap: () => _handleExperienceTap(index),
    );
  }

  Widget _buildExperienceView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var experiences = viewModel.experiences.value;
      if (experiences.isEmpty || index >= experiences.length) {
        return const SizedBox();
      }
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
              SizedBox(width: 80, child: Text(label, style: labelTextStyle)),
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
