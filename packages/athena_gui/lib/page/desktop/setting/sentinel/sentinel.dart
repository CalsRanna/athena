import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/component/sentinel_form_dialog.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
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

/// 桌面端 Sentinels：单列列表 → 点进一个角色的编辑页。
///
/// 编辑页有名字、头像、描述、标签、提示词五个字段，**改动先攒着**，底部
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
  int? openId;
  final _selection = DesktopListSelection<int>();
  final nameController = TextEditingController();
  final avatarController = TextEditingController();
  final descriptionController = TextEditingController();
  final tagsController = TextEditingController();
  final promptController = TextEditingController();
  bool dirty = false;
  String? nameError;
  String? promptError;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_recomputeDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _controllers => [
    nameController,
    avatarController,
    descriptionController,
    tagsController,
    promptController,
  ];

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final sentinels = viewModel.sentinels.value;
      final open = sentinels.where((s) => s.id == openId).firstOrNull;
      if (open == null) return _buildList(sentinels);
      return _buildEditor(open);
    });
  }

  // ---------------------------------------------------------------------------
  // 列表
  // ---------------------------------------------------------------------------

  Widget _buildList(List<SentinelEntity> sentinels) {
    var rows = <Widget>[
      for (final sentinel in sentinels) _buildSentinelRow(sentinel),
    ];
    if (rows.isEmpty) {
      rows = [
        AthenaSettingsEmptyState(
          icon: LucideIcons.bot,
          title: 'No Sentinels',
          hint:
              'A Sentinel is a reusable persona: a system prompt plus a name, '
              'description and tags.',
          action: AthenaSecondaryButton.small(
            onTap: createSentinel,
            child: const Text('New Sentinel'),
          ),
        ),
      ];
    }
    return AthenaSettingsPane(
      children: [
        AthenaSettingsSection(
          first: true,
          title: 'Sentinels',
          description:
              'Personas you can attach to a chat. Each one is a system prompt '
              'with a name, description and tags.',
          trailing: AthenaSecondaryButton.small(
            onTap: createSentinel,
            child: const Text('New Sentinel'),
          ),
          children: rows,
        ),
      ],
    );
  }

  Widget _buildSentinelRow(SentinelEntity sentinel) {
    final description = sentinel.description.trim();
    return AthenaSettingsRow(
      label: sentinel.name,
      badge: sentinel.isPreset ? 'Built-in' : null,
      description: description.isEmpty ? 'No description' : description,
      descriptionMaxLines: 1,
      leading: AthenaSettingsAvatar(text: _avatarGlyph(sentinel)),
      chevron: true,
      selected: _selection.selectedIds.contains(sentinel.id),
      onTap: () => _handleSentinelTap(sentinel),
      onSecondaryTap: (details) => _openContextMenu(details, sentinel),
    );
  }

  static String _avatarGlyph(SentinelEntity sentinel) {
    final avatar = sentinel.avatar.trim();
    if (avatar.isNotEmpty) return avatar.characters.first;
    final name = sentinel.name.trim();
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  void _handleSentinelTap(SentinelEntity sentinel) {
    final sentinels = viewModel.sentinels.value;
    final activate = _selection.handleTap(
      sentinel.id,
      ids: sentinels
          .where((item) => !item.isPreset && item.id != null)
          .map((item) => item.id!)
          .toList(),
    );
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
    var menu = DesktopContextMenu(
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
                ? 'Delete ${deletable.length} Sentinels…'
                : 'Delete…',
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
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final readOnly = sentinel.isPreset;
    final generating = viewModel.isGenerating.value;
    var header = Row(
      children: [
        AthenaSettingsBackLink(label: 'Sentinels', onTap: _closeEditor),
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
              onDiscard: () => _openSentinel(sentinel),
              onSave: () => storeSentinel(sentinel),
            )
          : null,
      children: [
        AthenaSettingsSection(
          first: true,
          title: readOnly ? sentinel.name : 'Identity',
          description: readOnly
              ? 'The built-in Sentinel can be read but not edited. Duplicate '
                    'it to make your own version.'
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
              label: 'Avatar',
              description: 'A single emoji shown next to the name.',
              control: SizedBox(
                width: AthenaSettingsControlWidth.narrow,
                child: AthenaSettingsTextField(
                  controller: avatarController,
                  enabled: !readOnly,
                  placeholder: '🦉',
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
              : 'Generate fills in the name, avatar, description and tags '
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
                      Text(generating ? 'Generating…' : 'Generate metadata'),
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
                    placeholder: 'You are…',
                  ),
                  if (promptError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      promptError!,
                      style: TextStyle(
                        color: colors.dangerText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!readOnly)
          AthenaSettingsSection(
            title: 'Danger zone',
            children: [
              AthenaSettingsRow(
                label: 'Delete Sentinel',
                description:
                    'Chats that used ${sentinel.name} keep their history but '
                    'lose the persona.',
                control: AthenaSecondaryButton.small(
                  onTap: () => destroySentinels([sentinel]),
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

  void _fill(SentinelEntity sentinel) {
    nameController.text = sentinel.name;
    avatarController.text = sentinel.avatar;
    descriptionController.text = sentinel.description;
    tagsController.text = sentinel.tags;
    promptController.text = sentinel.prompt;
  }

  void _recomputeDirty() {
    final sentinel = viewModel.sentinels.value
        .where((s) => s.id == openId)
        .firstOrNull;
    if (sentinel == null) return;
    final next =
        nameController.text != sentinel.name ||
        avatarController.text != sentinel.avatar ||
        descriptionController.text != sentinel.description ||
        tagsController.text != sentinel.tags ||
        promptController.text != sentinel.prompt;
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
    var copied = sentinel.copyWith(
      name: name,
      avatar: avatarController.text.trim(),
      description: descriptionController.text.trim(),
      tags: tagsController.text.trim(),
      prompt: prompt,
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
      var modelId = await _getModelId();
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
      if (avatarController.text.trim().isEmpty) {
        avatarController.text = generated.avatar;
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
      id: 0,
      name: '${source.name} copy',
      avatar: source.avatar,
      description: source.description,
      prompt: source.prompt,
      tags: source.tags,
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
          ? 'Delete ${deletable.single.name}?'
          : 'Delete ${deletable.length} Sentinels?',
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

  Future<int?> _getModelId() async {
    final settingViewModel = GetIt.instance<SettingViewModel>();
    final modelResolver = GetIt.instance<ModelResolver>();
    final model = await modelResolver.resolveModel(
      preferredModelId: settingViewModel.sentinelMetadataGenerationModelId.value,
    );
    if (model == null) {
      if (mounted) AthenaDialog.warning('No enabled models found');
      return null;
    }
    return model.id!;
  }
}
