import 'package:athena_core/agent/skill/skill_loader.dart';
import 'package:athena_gui/page/desktop/setting/skill/component/skill_form_dialog.dart';
import 'package:athena_gui/page/desktop/setting/component/form_field.dart';
import 'package:athena_gui/page/desktop/setting/component/list_pane.dart';
import 'package:athena_gui/theme/athena_settings.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/skill_view_model.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

enum _Source implements SettingsListOption {
  all('All sources'),
  user('Your skills'),
  builtin('Built-in');

  const _Source(this.label);
  @override
  final String label;
}

enum _Sort implements SettingsListOption {
  edited('Last edited'),
  name('Name');

  const _Sort(this.label);
  @override
  final String label;
}

/// 桌面端 Skills：按来源浏览，点进技能预览或编辑 Markdown。
///
/// 与 Sentinels 同一套交互：改动先攒着，底部粘性「未保存」栏；内置技能
/// 只读。技能名是目录名，创建后不可改（要改名就删了重建）。
@RoutePage()
class DesktopSettingSkillPage extends StatefulWidget {
  const DesktopSettingSkillPage({super.key});

  @override
  State<DesktopSettingSkillPage> createState() =>
      _DesktopSettingSkillPageState();
}

class _DesktopSettingSkillPageState extends State<DesktopSettingSkillPage> {
  late final viewModel = GetIt.instance<SkillViewModel>();

  (String, bool)? openId;
  final searchController = TextEditingController();
  _Source source = _Source.all;
  _Sort sort = _Sort.edited;
  bool showCode = false;
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
    searchController.dispose();
    descriptionController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final skills = viewModel.skills.value;
        final open = skills
            .where((s) => (s.name, s.isBuiltin) == openId)
            .firstOrNull;
        if (open == null) return _buildList(skills);
        return _buildEditor(open);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<Skill> skills) {
    final query = searchController.text.trim().toLowerCase();
    final matches = skills.where(
      (skill) =>
          skill.name.toLowerCase().contains(query) ||
          skill.description.toLowerCase().contains(query),
    );
    final user = matches.where((s) => !s.isBuiltin).toList()..sort(_compare);
    final builtin = matches.where((s) => s.isBuiltin).toList()..sort(_compare);
    final userIds = user.map((s) => s.name).toList();
    final groups = <Widget>[
      if (source != _Source.builtin && user.isNotEmpty)
        _buildGroup(_Source.user, user, userIds),
      if (source != _Source.user && builtin.isNotEmpty)
        _buildGroup(_Source.builtin, builtin, userIds),
    ];
    return AthenaSettingsListPane(
      title: 'Skills',
      searchController: searchController,
      onSearchChanged: (_) => setState(_selection.clear),
      filterBy: 'source',
      filter: source,
      filters: _Source.values,
      onFilterChanged: (option) => setState(() {
        source = option;
        _selection.clear();
      }),
      sort: sort,
      sorts: _Sort.values,
      onSortChanged: (option) => setState(() {
        sort = option;
        _selection.clear();
      }),
      onAdd: createSkill,
      children: [
        if (groups.isEmpty)
          AthenaSettingsEmptyState(
            icon: skills.isEmpty ? LucideIcons.scrollText : LucideIcons.search,
            title: skills.isEmpty ? 'No skills yet' : 'No matching skills',
            hint: skills.isEmpty
                ? 'Add a skill to give the agent reusable instructions.'
                : 'Try another search or change the source filter.',
          ),
        for (final group in groups) ...[
          if (group != groups.first)
            const SizedBox(height: AthenaSettings.sectionGap),
          group,
        ],
      ],
    );
  }

  int _compare(Skill a, Skill b) {
    if (sort == _Sort.edited) {
      final byDate = (b.modifiedAt?.microsecondsSinceEpoch ?? 0).compareTo(
        a.modifiedAt?.microsecondsSinceEpoch ?? 0,
      );
      if (byDate != 0) return byDate;
    }
    return a.name.compareTo(b.name);
  }

  Widget _buildGroup(_Source group, List<Skill> skills, List<String> userIds) {
    final colors = context.athenaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AthenaSettingsInset(
          child: Row(
            children: [
              Text(
                group.label,
                style: AthenaTextStyle.section.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: AthenaSpace.sm),
              AthenaSettingsBadge(text: '${skills.length}'),
            ],
          ),
        ),
        const SizedBox(height: AthenaSpace.sm),
        AthenaSettingsGroup(
          children: [
            for (final skill in skills) _buildSkillRow(skill, userIds),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillRow(Skill skill, List<String> userIds) {
    final colors = context.athenaColors;
    final date = skill.modifiedAt;
    final origin = skill.isBuiltin ? 'Athena' : 'Local skill';
    final items = _menuItems(skill);
    return AthenaSettingsListRow(
      label: skill.name,
      labelMaxLines: 1,
      leading: Container(
        width: AthenaSettings.controlHeight,
        height: AthenaSettings.controlHeight,
        decoration: BoxDecoration(
          color: colors.neutralControlFill,
          border: Border.all(color: colors.neutralBorder),
          borderRadius: BorderRadius.circular(AthenaRadius.control),
        ),
        child: Icon(
          LucideIcons.scrollText,
          size: AthenaIcon.regularSize,
          color: colors.iconSecondary,
        ),
      ),
      description: '$origin  ·  ${skill.description}',
      descriptionMaxLines: 1,
      metadata: date == null
          ? null
          : MaterialLocalizations.of(context).formatShortMonthDay(date),
      trailing: skill.isBuiltin
          ? const SizedBox(width: AthenaIconButtonSize.compact)
          : Tooltip(
              message: 'More actions for ${skill.name}',
              child: AthenaSettingsMenuButton(items: items, menuWidth: 180),
            ),
      selected: !skill.isBuiltin && _selection.selectedIds.contains(skill.name),
      onTap: () => _handleSkillTap(skill, userIds),
      onSecondaryTap: (details) {
        DesktopContextMenuManager.instance.show(
          context,
          DesktopContextMenu(
            offset: details.globalPosition,
            width: 180,
            children: items,
          ),
        );
      },
    );
  }

  void _handleSkillTap(Skill skill, List<String> userIds) {
    final activate = _selection.handleTap(
      skill.isBuiltin ? null : skill.name,
      ids: userIds,
    );
    if (activate) {
      _openSkill(skill);
    } else {
      setState(() {});
    }
  }

  void _openSkill(Skill skill, {bool code = false}) {
    _selection.clear();
    descriptionController.text = skill.description;
    bodyController.text = skill.body;
    setState(() {
      openId = (skill.name, skill.isBuiltin);
      showCode = code;
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
      openId = null;
      dirty = false;
    });
  }

  List<Widget> _menuItems(Skill skill) {
    final selectedIds = _selection.selectedIds;
    final multiSelect =
        !skill.isBuiltin &&
        selectedIds.length > 1 &&
        selectedIds.contains(skill.name);
    final targets = multiSelect
        ? viewModel.skills.value
              .where(
                (item) => !item.isBuiltin && selectedIds.contains(item.name),
              )
              .toList()
        : [skill];
    return [
      if (!multiSelect && openId == null)
        DesktopContextMenuTile(
          text: skill.isBuiltin ? 'View' : 'Edit',
          onTap: () => _openSkill(skill, code: !skill.isBuiltin),
        ),
      if (!multiSelect && !skill.isBuiltin)
        DesktopContextMenuTile(
          text: 'Show in Finder',
          onTap: () => _reveal(skill),
        ),
      if (!skill.isBuiltin) ...[
        const DesktopContextMenuSeparator(),
        DesktopContextMenuTile(
          text: multiSelect ? 'Delete ${targets.length} skills…' : 'Delete…',
          danger: true,
          onTap: () => destroySkills(targets),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // 编辑
  // ---------------------------------------------------------------------------

  Widget _buildEditor(Skill skill) {
    final colors = context.athenaColors;
    final readOnly = skill.isBuiltin;
    return AthenaSettingsPane(
      key: ValueKey(openId),
      title: skill.name,
      header: AthenaSettingsBackLink(label: 'Skills', onTap: _closeEditor),
      action: readOnly
          ? const AthenaSettingsBadge(text: 'Built-in')
          : Tooltip(
              message: 'More actions for ${skill.name}',
              child: AthenaSettingsMenuButton(items: _menuItems(skill)),
            ),
      // 保存栏出现时保持输入区挂载，避免首次输入后丢失焦点。
      footer: dirty && !readOnly
          ? AthenaSettingsSaveBar(
              onDiscard: () => _openSkill(skill, code: showCode),
              onSave: () => storeSkill(skill),
            )
          : const SizedBox.shrink(),
      children: [
        AthenaSettingsInset(
          child: Text(
            readOnly ? 'Built into Athena' : 'Local skill',
            style: AthenaTextStyle.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AthenaSpace.sm),
        if (showCode && !readOnly)
          AthenaSettingsInset(
            child: DesktopSettingFormField(
              label: 'Description',
              error: descriptionError,
              child: AthenaSettingsTextField(controller: descriptionController),
            ),
          )
        else
          AthenaSettingsParagraph(text: descriptionController.text),
        AthenaSettingsSection(
          title: 'Instructions',
          trailing: AthenaSettingsSegmented<bool>(
            selected: showCode,
            options: const [
              AthenaSegmentOption(value: false, label: 'Preview'),
              AthenaSegmentOption(value: true, label: 'Code'),
            ],
            onChanged: (code) => setState(() => showCode = code),
          ),
          children: [AthenaSettingsInset(child: _buildInstructions(readOnly))],
        ),
      ],
    );
  }

  Widget _buildInstructions(bool readOnly) {
    if (showCode) {
      if (readOnly) {
        return SelectableText(
          bodyController.text,
          style: AthenaTextStyle.captionCode.copyWith(
            color: context.athenaColors.textPrimary,
          ),
        );
      }
      return AthenaSettingsTextArea(
        controller: bodyController,
        minLines: 12,
        placeholder: '# When to use\n\n# Steps',
      );
    }
    if (bodyController.text.trim().isEmpty) {
      return Text(
        'No instructions yet.',
        style: AthenaTextStyle.row.copyWith(
          color: context.athenaColors.textSecondary,
        ),
      );
    }
    return MarkdownBody(data: bodyController.text, selectable: true);
  }

  void _recomputeDirty() {
    final skill = viewModel.skills.value
        .where((s) => (s.name, s.isBuiltin) == openId)
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
      descriptionError = description.isEmpty
          ? 'Description is required.'
          : null;
      if (descriptionError != null) showCode = true;
    });
    if (descriptionError != null) return;
    final ok = await viewModel.updateSkill(
      skill,
      description: description,
      body: bodyController.text,
    );
    if (!mounted) return;
    if (!ok) {
      AthenaDialog.error(viewModel.error.value ?? 'Failed to save skill');
      return;
    }
    final saved = viewModel.skills.value.firstWhere(
      (item) => !item.isBuiltin && item.name == skill.name,
    );
    _openSkill(saved, code: showCode);
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
          if (skill != null) _openSkill(skill, code: true);
        },
      ),
    );
  }

  Future<void> _reveal(Skill skill) async {
    final ok = await launchUrl(Uri.directory(skill.sourcePath));
    if (!ok && mounted) {
      AthenaDialog.error('Unable to open ${skill.sourcePath}');
    }
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
      if (deletable.any((item) => (item.name, item.isBuiltin) == openId)) {
        openId = null;
        dirty = false;
      }
    });
  }
}
