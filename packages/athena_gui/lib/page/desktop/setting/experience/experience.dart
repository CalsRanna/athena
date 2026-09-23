import 'package:athena_core/entity/experience_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/experience_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:athena_gui/widget/tag.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 桌面端 Experiences：单列列表（活跃 / 已归档两个分区）→ 点进只读详情。
///
/// 经验由 Agent 进化产出，不支持手工新建/编辑；归档、恢复、删除走行尾
/// `⋯` 菜单或右键，多选后批量归档 / 删除。
@RoutePage()
class DesktopSettingExperiencePage extends StatefulWidget {
  const DesktopSettingExperiencePage({super.key});

  @override
  State<DesktopSettingExperiencePage> createState() =>
      _DesktopSettingExperiencePageState();
}

class _DesktopSettingExperiencePageState
    extends State<DesktopSettingExperiencePage> {
  late final viewModel = GetIt.instance<ExperienceViewModel>();

  /// 正在查看的经验 `(sentinelId, id)`；null 表示停在列表。
  (String, String)? openKey;
  final _selection = DesktopListSelection<(String, String)>();

  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final experiences = viewModel.experiences.value;
      final open = experiences.where((e) => _keyOf(e) == openKey).firstOrNull;
      if (open == null) return _buildList(experiences);
      return _buildDetail(open);
    });
  }

  static (String, String) _keyOf(ExperienceEntity experience) =>
      (experience.sentinelId, experience.id);

  static bool _isArchived(ExperienceEntity experience) =>
      experience.status == ExperienceEntity.statusArchived;

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<ExperienceEntity> experiences) {
    final active = experiences.where((e) => !_isArchived(e)).toList();
    final archived = experiences.where(_isArchived).toList();
    var rows = <Widget>[for (final e in active) _buildExperienceRow(e)];
    if (rows.isEmpty) {
      rows = [
        const AthenaSettingsEmptyState(
          icon: LucideIcons.brain,
          title: 'Nothing learned yet',
          hint:
              'As the agent works it records lessons here and recalls them '
              'in later chats. Archive the ones you disagree with.',
        ),
      ];
    }
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Experiences',
          description:
              'Lessons the agent learned from earlier chats. Active ones are '
              'recalled automatically; archived ones are kept as a record '
              'but never used.',
          children: rows,
        ),
        if (archived.isNotEmpty)
          AthenaSettingsSection(
            title: 'Archived',
            children: [for (final e in archived) _buildExperienceRow(e)],
          ),
      ],
    );
  }

  Widget _buildExperienceRow(ExperienceEntity experience) {
    final archived = _isArchived(experience);
    final meta = <String>[
      viewModel.ownerLabel(experience),
      _formatDate(experience.createdAt),
      if (experience.tags.isNotEmpty) experience.tags.take(3).join(', '),
    ];
    return AthenaSettingsRow(
      label: experience.lesson,
      labelMaxLines: 2,
      description: meta.join(' · '),
      descriptionMaxLines: 1,
      dimmed: archived,
      chevron: true,
      selected: _selection.selectedIds.contains(_keyOf(experience)),
      onTap: () => _handleTap(experience),
      onSecondaryTap: (details) => _openContextMenu(details, experience),
    );
  }

  void _handleTap(ExperienceEntity experience) {
    final experiences = viewModel.experiences.value;
    final activate = _selection.handleTap(
      _keyOf(experience),
      ids: experiences.map(_keyOf).toList(),
    );
    if (activate) {
      _openExperience(experience);
    } else {
      setState(() {});
    }
  }

  void _openExperience(ExperienceEntity experience) {
    _selection.clear();
    setState(() => openKey = _keyOf(experience));
  }

  void _closeDetail() {
    setState(() => openKey = null);
  }

  List<Widget> _menuItems(ExperienceEntity experience, {bool open = true}) {
    final selected = viewModel.experiences.value
        .where((item) => _selection.selectedIds.contains(_keyOf(item)))
        .toList();
    final multiSelect = selected.length > 1 && selected.contains(experience);
    final targets = multiSelect ? selected : [experience];
    final archivable = targets.where((e) => !_isArchived(e)).toList();
    final restorable = targets.where(_isArchived).toList();
    return [
      if (!multiSelect && open)
        DesktopContextMenuTile(
          text: 'View',
          onTap: () => _openExperience(experience),
        ),
      if (archivable.isNotEmpty)
        DesktopContextMenuTile(
          text: archivable.length > 1
              ? 'Archive ${archivable.length}'
              : 'Archive',
          onTap: () => archiveExperiences(archivable),
        ),
      if (restorable.isNotEmpty)
        DesktopContextMenuTile(
          text: restorable.length > 1
              ? 'Restore ${restorable.length}'
              : 'Restore',
          onTap: () => restoreExperiences(restorable),
        ),
      const DesktopContextMenuSeparator(),
      DesktopContextMenuTile(
        text: targets.length > 1 ? 'Delete ${targets.length}…' : 'Delete…',
        danger: true,
        onTap: () => destroyExperiences(targets),
      ),
    ];
  }

  void _openContextMenu(TapUpDetails details, ExperienceEntity experience) {
    var menu = DesktopContextMenu(
      offset: details.globalPosition,
      width: 160,
      children: _menuItems(experience),
    );
    DesktopContextMenuManager.instance.show(context, menu);
  }

  // ---------------------------------------------------------------------------
  // 详情
  // ---------------------------------------------------------------------------

  Widget _buildDetail(ExperienceEntity experience) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final archived = _isArchived(experience);
    var header = Row(
      children: [
        AthenaSettingsBackLink(label: 'Experiences', onTap: _closeDetail),
        if (archived) ...[
          const SizedBox(width: 8),
          const AthenaSettingsBadge(text: 'Archived'),
        ],
      ],
    );
    var actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AthenaSecondaryButton.small(
          onTap: () => archived
              ? restoreExperiences([experience])
              : archiveExperiences([experience]),
          child: Text(archived ? 'Restore' : 'Archive'),
        ),
        const SizedBox(width: 8),
        AthenaSettingsMenuButton(
          items: _menuItems(experience, open: false),
        ),
      ],
    );
    return AthenaSettingsPane(
      header: header,
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Lesson',
          trailing: actions,
          children: [AthenaSettingsParagraph(text: experience.lesson)],
        ),
        if (experience.context.isNotEmpty)
          AthenaSettingsSection(
            title: 'Context',
            children: [AthenaSettingsParagraph(text: experience.context)],
          ),
        AthenaSettingsSection(
          title: 'Details',
          children: [
            AthenaSettingsRow(
              label: 'Owner',
              control: _value(viewModel.ownerLabel(experience), colors),
            ),
            AthenaSettingsRow(
              label: 'Scope',
              description: experience.scope == 'shared'
                  ? 'Visible to every Sentinel.'
                  : 'Only this Sentinel recalls it.',
              control: _value(experience.scope, colors),
            ),
            AthenaSettingsRow(
              label: 'Source',
              control: _value(experience.source, colors),
            ),
            AthenaSettingsRow(
              label: 'Created',
              control: _value(_formatDate(experience.createdAt), colors),
            ),
            if (experience.updatedAt != null)
              AthenaSettingsRow(
                label: 'Updated',
                control: _value(_formatDate(experience.updatedAt!), colors),
              ),
            if (experience.tags.isNotEmpty)
              AthenaSettingsRow(
                label: 'Tags',
                control: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in experience.tags)
                      AthenaTag.small(text: tag),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _value(String text, AthenaColors colors) {
    return Text(
      text,
      style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.3),
    );
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> archiveExperiences(List<ExperienceEntity> targets) async {
    for (final experience in targets) {
      if (_isArchived(experience)) continue;
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

  Future<void> restoreExperiences(List<ExperienceEntity> targets) async {
    for (final experience in targets) {
      if (!_isArchived(experience)) continue;
      final ok = await viewModel.restoreExperience(experience);
      if (!ok) {
        if (mounted) {
          AthenaDialog.warning(viewModel.error.value ?? 'Operation failed');
        }
        break;
      }
    }
    if (mounted) setState(_selection.clear);
  }

  Future<void> destroyExperiences(List<ExperienceEntity> targets) async {
    if (targets.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      targets.length == 1
          ? 'Delete this experience? This cannot be undone.'
          : 'Delete ${targets.length} experiences? This cannot be undone.',
    );
    if (confirmed != true) return;
    for (final experience in targets) {
      final ok = await viewModel.deleteExperience(experience);
      if (!ok) {
        if (mounted) {
          AthenaDialog.error(
            viewModel.error.value ?? 'Failed to delete experience',
          );
        }
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selection.clear();
      if (targets.any((e) => _keyOf(e) == openKey)) openKey = null;
    });
  }
}

String _formatDate(DateTime dt) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
}
