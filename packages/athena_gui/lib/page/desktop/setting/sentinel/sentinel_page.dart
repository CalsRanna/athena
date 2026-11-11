import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/component/sentinel_form_dialog.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/page/desktop/component/desktop_list_selection.dart';
import 'package:athena_gui/component/tool_config.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/page/desktop/component/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:athena_gui/page/desktop/setting/component/control.dart';
import 'package:athena_gui/page/desktop/setting/component/list_pane.dart';
import 'package:athena_gui/page/desktop/setting/component/panel.dart';
import 'package:athena_gui/page/desktop/setting/component/row.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

enum _Source implements SettingsListOption {
  all('All sources'),
  custom('Your Sentinels'),
  builtin('Built-in');

  const _Source(this.label);
  @override
  final String label;
}

enum _Sort implements SettingsListOption {
  ascending('Name (A–Z)'),
  descending('Name (Z–A)');

  const _Sort(this.label);
  @override
  final String label;
}

/// 桌面端 Sentinels：单列列表 → 点进一个角色的编辑页。
///
/// 编辑页有名字、描述、标签、提示词四个字段，**改动先攒着**，底部
/// 出现「未保存」粘性栏（Discard / Save）——提示词往往要改很久，逐字段
/// 失焦保存会把半成品写进磁盘。内置角色（Athena）只读：字段禁用、没有
/// 保存栏，标题带 `Built-in` 徽标。
///
/// 列表支持 ⌘ / ⇧ 多选与右键（批量删除自定义角色）；普通点击钻取。
@RoutePage()
class DesktopSettingSentinelPage extends StatefulWidget {
  const DesktopSettingSentinelPage({super.key});

  @override
  State<DesktopSettingSentinelPage> createState() =>
      _DesktopSettingSentinelPageState();
}

class _DesktopSettingSentinelPageState
    extends State<DesktopSettingSentinelPage> {
  late final viewModel = GetIt.instance<SentinelViewModel>();

  /// 正在编辑的角色；null 表示停在列表。
  String? openId;
  final searchController = TextEditingController();
  _Source source = _Source.all;
  _Sort sort = _Sort.ascending;
  final _selection = DesktopListSelection<String>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final tagsController = TextEditingController();
  final promptController = TextEditingController();
  bool dirty = false;
  String? nameError;
  String? promptError;

  /// 正在编辑的工具白名单；null = 全部可用。
  Set<String>? enabledToolsDraft;

  /// 当前平台实际注册的工具；设置页只展示真实存在的。
  late final List<Tool> registeredTools = GetIt.instance<ToolRegistry>().all;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_recomputeDirty);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _controllers => [
    nameController,
    descriptionController,
    tagsController,
    promptController,
  ];

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final sentinels = viewModel.sentinels.value;
        final open = sentinels.where((s) => s.id == openId).firstOrNull;
        if (open == null) return _buildList(sentinels);
        return _buildEditor(open);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<SentinelEntity> sentinels) {
    final query = searchController.text.trim().toLowerCase();
    final matches = sentinels.where((s) {
      if (source == _Source.custom && s.isPreset ||
          source == _Source.builtin && !s.isPreset) {
        return false;
      }
      return s.name.toLowerCase().contains(query) ||
          s.description.toLowerCase().contains(query) ||
          s.tags.toLowerCase().contains(query);
    }).toList();
    matches.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return sort == _Sort.ascending ? byName : -byName;
      return (a.id ?? '').compareTo(b.id ?? '');
    });
    final selectableIds = [
      for (final s in matches)
        if (!s.isPreset && s.id != null) s.id!,
    ];
    return AthenaSettingsListPane(
      title: 'Sentinels',
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
      onAdd: createSentinel,
      children: [
        if (sentinels.isEmpty)
          AthenaSettingsEmptyState(
            icon: LucideIcons.userRound,
            title: 'No Sentinels',
            hint:
                'A Sentinel is a reusable persona: a system prompt plus a name, '
                'description and tags.',
            action: AthenaSecondaryButton.small(
              onTap: createSentinel,
              child: const Text('New Sentinel'),
            ),
          )
        else if (matches.isEmpty)
          const AthenaSettingsEmptyState(
            icon: LucideIcons.search,
            title: 'No matching Sentinels',
            hint: 'Try another search or change the source filter.',
          )
        else
          AthenaSettingsSection(
            first: true,
            title: 'Sentinels · ${matches.length}',
            children: [
              for (final sentinel in matches)
                _buildSentinelRow(sentinel, selectableIds),
            ],
          ),
      ],
    );
  }

  Widget _buildSentinelRow(
    SentinelEntity sentinel,
    List<String> selectableIds,
  ) {
    final description = sentinel.description.trim();
    return AthenaSettingsListRow(
      label: sentinel.name,
      badge: sentinel.isPreset ? 'Built-in' : null,
      description: description.isEmpty ? 'No description' : description,
      descriptionMaxLines: 1,
      selected: _selection.selectedIds.contains(sentinel.id),
      onTap: () => _handleSentinelTap(sentinel, selectableIds),
      onSecondaryTap: (details) => _openContextMenu(details, sentinel),
    );
  }

  void _handleSentinelTap(SentinelEntity sentinel, List<String> selectableIds) {
    final activate = _selection.handleTap(sentinel.id, ids: selectableIds);
    if (activate) {
      _openSentinel(sentinel);
    } else {
      setState(() {});
    }
  }

  void _openSentinel(SentinelEntity sentinel) {
    _selection.clear();
    _fill(sentinel);
    setState(() {
      openId = sentinel.id;
      dirty = false;
      nameError = null;
      promptError = null;
    });
  }

  Future<void> _closeEditor() async {
    if (dirty) {
      final leave = await AthenaDialog.confirm(
        'Discard unsaved changes to this Sentinel?',
      );
      if (leave != true || !mounted) return;
    }
    setState(() {
      openId = null;
      dirty = false;
    });
  }

  void _openContextMenu(TapUpDetails details, SentinelEntity sentinel) {
    final selected = viewModel.sentinels.value
        .where((item) => _selection.selectedIds.contains(item.id))
        .toList();
    final multiSelect = selected.length > 1 && selected.contains(sentinel);
    final targets = multiSelect ? selected : [sentinel];
    final deletable = targets.where((item) => !item.isPreset).toList();
    final menu = DesktopContextMenu(
      offset: details.globalPosition,
      width: 160,
      children: [
        if (!multiSelect)
          DesktopContextMenuTile(
            text: sentinel.isPreset ? 'View' : 'Edit',
            onTap: () => _openSentinel(sentinel),
          ),
        if (!multiSelect)
          DesktopContextMenuTile(
            text: 'Duplicate',
            onTap: () => duplicateSentinel(sentinel),
          ),
        if (deletable.isNotEmpty) const DesktopContextMenuSeparator(),
        if (deletable.isNotEmpty)
          DesktopContextMenuTile(
            text: deletable.length > 1
                ? 'Delete ${deletable.length} Sentinels'
                : 'Delete',
            danger: true,
            onTap: () => destroySentinels(deletable),
          ),
      ],
    );
    DesktopContextMenuManager.instance.show(context, menu);
  }

  // ---------------------------------------------------------------------------
  // 编辑
  // ---------------------------------------------------------------------------

  Widget _buildEditor(SentinelEntity sentinel) {
    final colors = context.athenaColors;
    final readOnly = sentinel.isPreset;
    final generating = viewModel.isGenerating.value;
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AthenaSettingsBackLink(label: 'Sentinels', onTap: _closeEditor),
        if (readOnly) ...[
          const SizedBox(width: 8),
          const AthenaSettingsBadge(text: 'Built-in'),
        ],
      ],
    );
    return AthenaSettingsPane(
      title: sentinel.name,
      header: header,
      footer: dirty
          ? AthenaSettingsSaveBar(
              onDiscard: () => _openSentinel(sentinel),
              onSave: () => storeSentinel(sentinel),
            )
          : null,
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Identity',
          description: readOnly
              ? 'The built-in Sentinel\'s identity and prompt are locked. '
                    'Its tools can still be changed; duplicate it to make your '
                    'own version.'
              : null,
          trailing: readOnly
              ? AthenaSecondaryButton.small(
                  onTap: () => duplicateSentinel(sentinel),
                  child: const Text('Duplicate'),
                )
              : null,
          children: [
            if (!readOnly)
              AthenaSettingsRow(
                label: 'Name',
                error: nameError,
                control: SizedBox(
                  width: AthenaSettingsControlWidth.wide,
                  child: AthenaSettingsTextField(
                    controller: nameController,
                    placeholder: 'e.g. Code reviewer',
                  ),
                ),
              ),
            AthenaSettingsRow(
              label: 'Description',
              description: 'One line shown in the Sentinel list and picker.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: descriptionController,
                  enabled: !readOnly,
                ),
              ),
            ),
            AthenaSettingsRow(
              label: 'Tags',
              description: 'Comma-separated.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.wide,
                child: AthenaSettingsTextField(
                  controller: tagsController,
                  enabled: !readOnly,
                  placeholder: 'writing, review',
                ),
              ),
            ),
          ],
        ),
        AthenaSettingsSection(
          title: 'System prompt',
          description: readOnly
              ? null
              : 'Generate fills in the name, description and tags '
                    'from this prompt using the Sentinel metadata model.',
          trailing: readOnly
              ? null
              : AthenaSecondaryButton.small(
                  onTap: generating ? null : generateSentinel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (generating)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            color: colors.textSecondary,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        const Icon(LucideIcons.sparkles),
                      const SizedBox(width: 6),
                      Text(generating ? 'Generating' : 'Generate metadata'),
                    ],
                  ),
                ),
          children: [
            AthenaSettingsInset(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AthenaSettingsTextArea(
                    controller: promptController,
                    enabled: !readOnly,
                    minLines: 14,
                    placeholder: 'You are',
                  ),
                  if (promptError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      promptError!,
                      style: AthenaTextStyle.caption.copyWith(
                        color: colors.dangerText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        _buildToolsSection(),
        if (!readOnly)
          AthenaSettingsSection(
            title: 'Danger zone',
            children: [
              AthenaSettingsRow(
                label: 'Delete Sentinel',
                description:
                    'Sessions that used ${sentinel.name} keep their history but '
                    'lose the persona. Its private experiences and evolution '
                    'history are deleted too.',
                control: AthenaSecondaryButton.small(
                  onTap: () => destroySentinels([sentinel]),
                  child: Text(
                    'Delete',
                    style: AthenaTextStyle.label.copyWith(
                      color: colors.dangerText,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _fill(SentinelEntity sentinel) {
    nameController.text = sentinel.name;
    descriptionController.text = sentinel.description;
    tagsController.text = sentinel.tags;
    promptController.text = sentinel.prompt;
    enabledToolsDraft = sentinel.enabledTools?.toSet();
  }

  /// 工具区按固定顺序展示；未登记的工具排在最后。
  List<Tool> get _displayTools =>
      ToolConfig.orderedToolsForConfig(registeredTools);

  bool _isToolOn(String name) =>
      ToolSet.kUndeactivatableToolNames.contains(name) ||
      (enabledToolsDraft?.contains(name) ?? true);

  void _setToolEnabled(String name, bool enabled) {
    final all = registeredTools.map((tool) => tool.name).toSet();
    final next = {
      ...?enabledToolsDraft,
      // 从「全部」收窄时补上目录里的全部已知工具，而不只是当前平台注册的：
      // 否则在移动端关掉一个工具，会把桌面端的文件与 Shell 工具一起写掉。
      if (enabledToolsDraft == null) ...all,
      if (enabledToolsDraft == null) ...ToolConfig.kToolConfigOrder,
      ...ToolSet.kUndeactivatableToolNames,
    };
    if (enabled) {
      next.add(name);
    } else {
      next.remove(name);
    }
    setState(() {
      // 全部选中等价于「不限制」：存回 null，新增工具才会自动出现。
      enabledToolsDraft = next.containsAll(all) ? null : next;
    });
    _recomputeDirty();
  }

  Widget _buildToolsSection() {
    return AthenaSettingsSection(
      title: 'Tools',
      description:
          'Choose which tools this Sentinel can use. Tools marked Always on '
          'are required by the engine.',
      children: [
        for (final tool in _displayTools)
          AthenaSettingsRow(
            label: ToolConfig.kToolConfigCopy[tool.name]?.$1 ?? tool.name,
            description:
                ToolConfig.kToolConfigCopy[tool.name]?.$2 ??
                tool.description.split('\n').first,
            badge: ToolSet.kUndeactivatableToolNames.contains(tool.name)
                ? 'Always on'
                : null,
            control: AthenaSwitch(
              value: _isToolOn(tool.name),
              onChanged: ToolSet.kUndeactivatableToolNames.contains(tool.name)
                  ? null
                  : (enabled) => _setToolEnabled(tool.name, enabled),
            ),
          ),
      ],
    );
  }

  void _recomputeDirty() {
    final sentinel = viewModel.sentinels.value
        .where((s) => s.id == openId)
        .firstOrNull;
    if (sentinel == null) return;
    final next =
        nameController.text != sentinel.name ||
        descriptionController.text != sentinel.description ||
        tagsController.text != sentinel.tags ||
        promptController.text != sentinel.prompt ||
        !setEquals(enabledToolsDraft, sentinel.enabledTools?.toSet());
    if (next != dirty && mounted) setState(() => dirty = next);
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> storeSentinel(SentinelEntity sentinel) async {
    final name = nameController.text.trim();
    final prompt = promptController.text;
    setState(() {
      nameError = name.isEmpty ? 'Name is required.' : null;
      promptError = prompt.trim().isEmpty ? 'System prompt is required.' : null;
    });
    if (nameError != null || promptError != null) return;
    final copied = sentinel.copyWith(
      name: name,
      description: descriptionController.text.trim(),
      tags: tagsController.text.trim(),
      prompt: prompt,
      enabledTools: enabledToolsDraft == null
          ? null
          : (enabledToolsDraft!.toList()..sort()),
    );
    await viewModel.updateSentinel(copied);
    if (!mounted) return;
    final error = viewModel.error.value;
    if (error != null) {
      AthenaDialog.error(error);
      return;
    }
    setState(() => dirty = false);
    AthenaDialog.success('Sentinel saved');
  }

  Future<void> generateSentinel() async {
    if (viewModel.isGenerating.value) return;
    if (promptController.text.trim().isEmpty) {
      setState(() => promptError = 'Write the system prompt first.');
      return;
    }
    setState(() => promptError = null);
    try {
      final modelId = await _getModelId();
      if (modelId == null) return;
      final generated = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (!mounted) return;
      if (generated == null) {
        AthenaDialog.error(viewModel.error.value ?? 'Generation failed');
        return;
      }
      // 只填空的字段：用户已经写好的名字不该被覆盖
      if (nameController.text.trim().isEmpty) {
        nameController.text = generated.name;
      }
      if (descriptionController.text.trim().isEmpty) {
        descriptionController.text = generated.description;
      }
      if (tagsController.text.trim().isEmpty) {
        tagsController.text = generated.tags;
      }
    } catch (error) {
      if (mounted) AthenaDialog.error(error.toString());
    }
  }

  void createSentinel() {
    AthenaDialog.show(
      DesktopSentinelFormDialog(
        onStored: (sentinel) {
          if (mounted) _openSentinel(sentinel);
        },
      ),
    );
  }

  Future<void> duplicateSentinel(SentinelEntity source) async {
    final copy = SentinelEntity(
      name: '${source.name} copy',
      description: source.description,
      prompt: source.prompt,
      tags: source.tags,
      enabledTools: source.enabledTools,
    );
    final created = await viewModel.createSentinel(copy);
    if (!mounted) return;
    if (created == null) {
      AthenaDialog.error(viewModel.error.value ?? 'Failed to duplicate');
      return;
    }
    _openSentinel(created);
  }

  Future<void> destroySentinels(List<SentinelEntity> targets) async {
    final deletable = targets
        .where((item) => !item.isPreset && item.id != null)
        .toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Delete ${deletable.single.name}?\n\n'
                'Its private experiences and evolution history are deleted '
                'with it. Shared experiences are kept. This cannot be undone.'
          : 'Delete ${deletable.length} Sentinels?\n\n'
                'Their private experiences and evolution history are deleted '
                'with them. Shared experiences are kept. This cannot be '
                'undone.',
    );
    if (confirmed != true) return;
    for (final sentinel in deletable) {
      await viewModel.deleteSentinel(sentinel);
      if (viewModel.sentinels.value.any((item) => item.id == sentinel.id)) {
        if (mounted) {
          AthenaDialog.error(
            viewModel.error.value ?? 'Failed to delete sentinel',
          );
        }
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selection.clear();
      if (deletable.any((item) => item.id == openId)) {
        openId = null;
        dirty = false;
      }
    });
  }

  Future<String?> _getModelId() async {
    final settingViewModel = GetIt.instance<SettingViewModel>();
    final modelResolver = GetIt.instance<ModelResolver>();
    final model = await modelResolver.resolveModel(
      preferredModelId:
          settingViewModel.sentinelMetadataGenerationModelId.value,
    );
    if (model == null) {
      if (mounted) AthenaDialog.warning('No enabled models found');
      return null;
    }
    return model.id!;
  }
}
