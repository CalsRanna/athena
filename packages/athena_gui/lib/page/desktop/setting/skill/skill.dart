import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/page/desktop/setting/skill/component/skill_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/settings/control.dart';
import 'package:athena_gui/widget/settings/panel.dart';
import 'package:athena_gui/widget/settings/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 桌面端 Skills：单列列表 → 点进一个技能的编辑页。
///
/// 与 Sentinels 同一套交互：改动先攒着，底部粘性「未保存」栏；内置技能
/// （self-evolve）只读。技能名是目录名，创建后不可改（要改名就删了重建）。
@RoutePage()
class DesktopSettingSkillPage extends StatefulWidget {
  const DesktopSettingSkillPage({super.key});

  @override
  State<DesktopSettingSkillPage> createState() =>
      _DesktopSettingSkillPageState();
}

class _DesktopSettingSkillPageState extends State<DesktopSettingSkillPage> {
  late final viewModel = GetIt.instance<SkillViewModel>();

  /// 正在编辑的技能名；null 表示停在列表。
  String? openName;
  final _selection = DesktopListSelection<String>();
  final descriptionController = TextEditingController();
  final bodyController = TextEditingController();
  bool dirty = false;
  String? descriptionError;

  @override
  void initState() {
    super.initState();
    descriptionController.addListener(_recomputeDirty);
    bodyController.addListener(_recomputeDirty);
    viewModel.load();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final skills = viewModel.skills.value;
      final open = skills.where((s) => s.name == openName).firstOrNull;
      if (open == null) return _buildList(skills);
      return _buildEditor(open);
    });
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<Skill> skills) {
    final user = skills.where((s) => !s.isBuiltin).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final builtin = skills.where((s) => s.isBuiltin).toList();
    var rows = <Widget>[for (final skill in user) _buildSkillRow(skill)];
    if (rows.isEmpty) {
      rows = [
        AthenaSettingsEmptyState(
          icon: LucideIcons.bookOpen,
          title: 'No skills yet',
          hint:
              'A skill is a SKILL.md the agent loads on demand: a short '
              'description plus step-by-step instructions. The agent can also '
              'write its own.',
          action: AthenaSecondaryButton.small(
            onTap: createSkill,
            child: const Text('New skill'),
          ),
        ),
      ];
    }
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Skills',
          description:
              'Reusable instructions the agent loads when a task matches. '
              'Stored as SKILL.md files under ~/.athena/skills.',
          trailing: AthenaSecondaryButton.small(
            onTap: createSkill,
            child: const Text('New skill'),
          ),
          children: rows,
        ),
        if (builtin.isNotEmpty)
          AthenaSettingsSection(
            title: 'Built-in',
            description: 'Ships with Athena and cannot be edited.',
            children: [for (final skill in builtin) _buildSkillRow(skill)],
          ),
      ],
    );
  }

  Widget _buildSkillRow(Skill skill) {
    final description = skill.description.trim();
    return AthenaSettingsRow(
      label: skill.name,
      badge: skill.isBuiltin ? 'Built-in' : null,
      description: description.isEmpty ? 'No description' : description,
      descriptionMaxLines: 1,
      chevron: true,
      selected: _selection.selectedIds.contains(skill.name),
      onTap: () => _handleSkillTap(skill),
      onSecondaryTap: (details) => _openContextMenu(details, skill),
    );
  }

  void _handleSkillTap(Skill skill) {
    final skills = viewModel.skills.value;
    final activate = _selection.handleTap(
      skill.name,
      ids: skills.where((item) => !item.isBuiltin).map((s) => s.name).toList(),
    );
    if (activate) {
      _openSkill(skill);
    } else {
      setState(() {});
    }
  }

  void _openSkill(Skill skill) {
    _selection.clear();
    descriptionController.text = skill.description;
    bodyController.text = skill.body;
    setState(() {
      openName = skill.name;
      dirty = false;
      descriptionError = null;
    });
  }

  Future<void> _closeEditor() async {
    if (dirty) {
      final leave = await AthenaDialog.confirm(
        'Discard unsaved changes to this skill?',
      );
      if (leave != true || !mounted) return;
    }
    setState(() {
      openName = null;
      dirty = false;
    });
  }

  void _openContextMenu(TapUpDetails details, Skill skill) {
    final selected = viewModel.skills.value
        .where((item) => _selection.selectedIds.contains(item.name))
        .toList();
    final multiSelect = selected.length > 1 && selected.contains(skill);
    final targets = multiSelect ? selected : [skill];
    final deletable = targets.where((item) => !item.isBuiltin).toList();
    var menu = DesktopContextMenu(
      offset: details.globalPosition,
      width: 180,
      children: [
        if (!multiSelect)
          DesktopContextMenuTile(
            text: skill.isBuiltin ? 'View' : 'Edit',
            onTap: () => _openSkill(skill),
          ),
        if (!multiSelect && !skill.isBuiltin)
          DesktopContextMenuTile(
            text: 'Show in Finder',
            onTap: () => _reveal(skill),
          ),
        if (deletable.isNotEmpty) const DesktopContextMenuSeparator(),
        if (deletable.isNotEmpty)
          DesktopContextMenuTile(
            text: deletable.length > 1
                ? 'Delete ${deletable.length} skills…'
                : 'Delete…',
            danger: true,
            onTap: () => destroySkills(deletable),
          ),
      ],
    );
    DesktopContextMenuManager.instance.show(context, menu);
  }

  // ---------------------------------------------------------------------------
  // 编辑
  // ---------------------------------------------------------------------------

  Widget _buildEditor(Skill skill) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final readOnly = skill.isBuiltin;
    var header = Row(
      children: [
        AthenaSettingsBackLink(label: 'Skills', onTap: _closeEditor),
        if (readOnly) ...[
          const SizedBox(width: 8),
          const AthenaSettingsBadge(text: 'Built-in'),
        ],
      ],
    );
    return AthenaSettingsPane(
      header: header,
      footer: dirty && !readOnly
          ? AthenaSettingsSaveBar(
              onDiscard: () => _openSkill(skill),
              onSave: () => storeSkill(skill),
            )
          : null,
      children: [
        AthenaSettingsSection(
          first: true,
          title: skill.name,
          description: readOnly
              ? 'Ships with Athena and cannot be edited.'
              : 'The name is the folder name and cannot be changed.',
          trailing: readOnly
              ? null
              : AthenaSecondaryButton.small(
                  onTap: () => _reveal(skill),
                  child: const Text('Show in Finder'),
                ),
          children: [
            AthenaSettingsRow(
              label: 'Description',
              description:
                  'One sentence the agent reads to decide when this skill '
                  'applies.',
              error: descriptionError,
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: descriptionController,
                  enabled: !readOnly,
                ),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'Instructions',
          description: readOnly
              ? null
              : 'Markdown. Loaded in full once the agent picks this skill.',
          children: [
            AthenaSettingsInset(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: AthenaSettingsTextArea(
                controller: bodyController,
                enabled: !readOnly,
                minLines: 16,
                mono: true,
                placeholder: '# When to use\n\n# Steps\n',
              ),
            ),
          ],
        ),
        if (!readOnly)
          AthenaSettingsSection(
            title: 'Danger zone',
            children: [
              AthenaSettingsRow(
                label: 'Delete skill',
                description: 'Removes the folder and everything in it.',
                control: AthenaSecondaryButton.small(
                  onTap: () => destroySkills([skill]),
                  child: Text(
                    'Delete…',
                    style: TextStyle(color: colors.dangerText),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _recomputeDirty() {
    final skill = viewModel.skills.value
        .where((s) => s.name == openName)
        .firstOrNull;
    if (skill == null) return;
    final next =
        descriptionController.text != skill.description ||
        bodyController.text != skill.body;
    if (next != dirty && mounted) setState(() => dirty = next);
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> storeSkill(Skill skill) async {
    final description = descriptionController.text.trim();
    setState(() {
      descriptionError = description.isEmpty ? 'Description is required.' : null;
    });
    if (descriptionError != null) return;
    var ok = await viewModel.updateSkill(
      skill,
      description: description,
      body: bodyController.text,
    );
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.error(viewModel.error.value ?? 'Failed to save skill');
      return;
    }
    setState(() => dirty = false);
    AthenaDialog.success('Skill saved');
  }

  void createSkill() {
    AthenaDialog.show(
      DesktopSkillFormDialog(
        onStored: (name) {
          if (!mounted) return;
          final skill = viewModel.skills.value
              .where((s) => s.name == name)
              .firstOrNull;
          if (skill != null) _openSkill(skill);
        },
      ),
    );
  }

  Future<void> _reveal(Skill skill) async {
    final ok = await launchUrl(Uri.directory(skill.sourcePath));
    if (!ok && mounted) AthenaDialog.error('Unable to open ${skill.sourcePath}');
  }

  Future<void> destroySkills(List<Skill> targets) async {
    final deletable = targets.where((item) => !item.isBuiltin).toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Delete ${deletable.single.name} and its folder?'
          : 'Delete ${deletable.length} skills and their folders?',
    );
    if (confirmed != true) return;
    for (final skill in deletable) {
      final ok = await viewModel.deleteSkill(skill);
      if (!ok) {
        if (mounted) {
          AthenaDialog.error(viewModel.error.value ?? 'Failed to delete skill');
        }
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selection.clear();
      if (deletable.any((item) => item.name == openName)) {
        openName = null;
        dirty = false;
      }
    });
  }
}
