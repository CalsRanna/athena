import 'package:athena_core/agent/tool/tool_interface.dart';
import 'package:athena_core/agent/tool/tool_registry.dart';
import 'package:athena_core/agent/tool/tool_set.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/util/tool_config_util.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:athena_gui/widget/switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:athena_gui/extension/athena_theme_context.dart';

@RoutePage()
class MobileSentinelFormPage extends StatefulWidget {
  final SentinelEntity? sentinel;
  const MobileSentinelFormPage({super.key, this.sentinel});

  @override
  State<MobileSentinelFormPage> createState() => _MobileSentinelFormPageState();
}

class _MobileSentinelFormPageState extends State<MobileSentinelFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final promptController = TextEditingController();
  final tagsController = TextEditingController();

  late final viewModel = GetIt.instance<SentinelViewModel>();

  /// 正在编辑的工具白名单；null = 全部可用。
  Set<String>? enabledToolsDraft;

  /// 当前平台实际注册的工具；表单只展示真实存在的。
  late final List<Tool> registeredTools = GetIt.instance<ToolRegistry>().all;

  @override
  Widget build(BuildContext context) {
    final isPreset = widget.sentinel?.isPreset ?? false;
    final colors = context.athenaColors;
    final listViewChildren = [
      if (isPreset)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'The built-in Sentinel\'s identity and prompt are locked. '
            'Its tools can still be changed.',
            style: AthenaTextStyle.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      if (isPreset) const SizedBox(height: 16),
      AthenaFormField(
        label: 'Prompt',
        control: AthenaInput(
          controller: promptController,
          enabled: !isPreset,
          maxLines: 8,
          minLines: 8,
        ),
      ),
      const SizedBox(height: 32),
      AthenaFormField(
        label: 'Name',
        control: AthenaInput(
          controller: nameController,
          enabled: !isPreset,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        trailing: isPreset ? null : _buildGenerateIcon(generateSentinelName),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Description',
        control: AthenaInput(
          controller: descriptionController,
          enabled: !isPreset,
          maxLines: 4,
          minLines: 4,
        ),
        trailing: isPreset
            ? null
            : _buildGenerateIcon(generateSentinelDescription),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Tags',
        control: AthenaInput(
          controller: tagsController,
          enabled: !isPreset,
          placeholder: 'writing, review',
          autocorrect: false,
          enableSuggestions: false,
        ),
        description: 'Comma-separated.',
      ),
      const SizedBox(height: 32),
      _buildToolsSection(context),
      const SizedBox(height: 16),
    ];
    final listView = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    final columnChildren = [Expanded(child: listView), _buildButtons(context)];
    final column = Column(children: columnChildren);
    return AthenaScaffold(
      appBar: AthenaAppBar(
        title: Text(widget.sentinel?.name ?? 'New Sentinel'),
      ),
      body: SafeArea(top: false, child: column),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final isPreset = widget.sentinel?.isPreset ?? false;
    final children = [
      Expanded(child: _buildStoreButton(context)),
      if (!isPreset) ...[
        const SizedBox(width: 8),
        Expanded(child: _buildGenerateButton(context)),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(children: children),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    final colors = context.athenaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AthenaFormTileLabel.large(title: 'Tools'),
        const SizedBox(height: 8),
        Text(
          'Choose which tools this Sentinel can use. Tools marked Always on '
          'are required by the engine.',
          style: AthenaTextStyle.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final tool in orderedToolsForConfig(registeredTools))
          _buildToolRow(context, tool),
      ],
    );
  }

  Widget _buildToolRow(BuildContext context, Tool tool) {
    final colors = context.athenaColors;
    final locked = kUndeactivatableToolNames.contains(tool.name);
    final copy = kToolConfigCopy[tool.name];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        copy?.$1 ?? tool.name,
                        style: AthenaTextStyle.row.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Always on',
                        style: AthenaTextStyle.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  copy?.$2 ?? tool.description.split('\n').first,
                  style: AthenaTextStyle.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AthenaSwitch(
              value: _isToolOn(tool.name),
              onChanged: locked
                  ? null
                  : (enabled) => _setToolEnabled(tool.name, enabled),
            ),
          ),
        ],
      ),
    );
  }

  bool _isToolOn(String name) =>
      kUndeactivatableToolNames.contains(name) ||
      (enabledToolsDraft?.contains(name) ?? true);

  void _setToolEnabled(String name, bool enabled) {
    final all = registeredTools.map((tool) => tool.name).toSet();
    final next = {
      ...?enabledToolsDraft,
      // 从「全部」收窄时补上目录里的全部已知工具，而不只是当前平台注册的：
      // 否则在移动端关掉一个工具，会把桌面端的文件与 Shell 工具一起写掉。
      if (enabledToolsDraft == null) ...all,
      if (enabledToolsDraft == null) ...kToolConfigOrder,
      ...kUndeactivatableToolNames,
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
  }

  List<String>? get _enabledToolsForSave =>
      enabledToolsDraft == null ? null : (enabledToolsDraft!.toList()..sort());

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    promptController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> generateSentinel() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.warning('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      final modelId = await _getModelId();
      if (modelId == null) return;
      final sentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (sentinel != null) {
        nameController.text = sentinel.name;
        descriptionController.text = sentinel.description;
      } else {
        AthenaDialog.error(viewModel.error.value ?? 'Generation failed');
      }
    } finally {
      AthenaDialog.dismiss();
    }
  }

  Future<void> generateSentinelDescription() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.warning('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      final modelId = await _getModelId();
      if (modelId == null) return;
      final description = await viewModel.generateSentinelDescription(
        promptController.text,
        modelId: modelId,
        existingName: nameController.text,
      );
      if (description != null) {
        descriptionController.text = description;
      } else {
        AthenaDialog.error(viewModel.error.value ?? 'Generation failed');
      }
    } finally {
      AthenaDialog.dismiss();
    }
  }

  Future<void> generateSentinelName() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.warning('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      final modelId = await _getModelId();
      if (modelId == null) return;
      final name = await viewModel.generateSentinelName(
        promptController.text,
        modelId: modelId,
      );
      if (name != null) {
        nameController.text = name;
      } else {
        AthenaDialog.error(viewModel.error.value ?? 'Generation failed');
      }
    } finally {
      AthenaDialog.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    nameController.text = widget.sentinel?.name ?? '';
    descriptionController.text = widget.sentinel?.description ?? '';
    promptController.text = widget.sentinel?.prompt ?? '';
    tagsController.text = widget.sentinel?.tags ?? '';
    enabledToolsDraft = widget.sentinel?.enabledTools?.toSet();
  }

  Future<void> storeSentinel() async {
    final message = _validate();
    if (message != null) return AthenaDialog.warning(message);
    if (widget.sentinel == null) return _store();
    _update();
  }

  /// 标签行右端的「生成」星标，点一下让模型填这个字段。
  Widget _buildGenerateIcon(VoidCallback onTap) {
    final colors = context.athenaColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(
        LucideIcons.sparkles,
        color: colors.textPrimary,
        size: AthenaIcon.regularSize,
      ),
    );
  }

  Widget _buildGenerateButton(BuildContext context) {
    return AthenaPrimaryButton(
      onTap: generateSentinel,
      child: const Center(child: Text('Generate')),
    );
  }

  Widget _buildStoreButton(BuildContext context) {
    return AthenaPrimaryButton(
      onTap: storeSentinel,
      child: const Center(child: Text('Store')),
    );
  }

  Future<void> _store() async {
    final sentinel = SentinelEntity(
      name: nameController.text,
      description: descriptionController.text,
      tags: tagsController.text,
      prompt: promptController.text,
      enabledTools: _enabledToolsForSave,
    );
    final created = await viewModel.createSentinel(sentinel);
    if (!mounted) return;
    if (created == null) {
      AthenaDialog.warning(viewModel.error.value ?? 'Failed to save Sentinel');
      return;
    }
    AutoRouter.of(context).maybePop();
  }

  Future<void> _update() async {
    final sentinel = widget.sentinel!.copyWith(
      name: nameController.text,
      description: descriptionController.text,
      tags: tagsController.text,
      prompt: promptController.text,
      enabledTools: _enabledToolsForSave,
    );
    await viewModel.updateSentinel(sentinel);
    if (!mounted) return;
    final error = viewModel.error.value;
    if (error != null) {
      AthenaDialog.warning(error);
      return;
    }
    AutoRouter.of(context).maybePop();
  }

  String? _validate() {
    // 内置角色只开放 Tools：身份与提示词取自原实体，不参与校验。
    if (widget.sentinel?.isPreset ?? false) return null;
    if (nameController.text.isEmpty) return 'Name is required';
    if (descriptionController.text.isEmpty) return 'Description is required';
    if (promptController.text.isEmpty) return 'Prompt is required';
    return null;
  }

  Future<String?> _getModelId() async {
    final settingViewModel = GetIt.instance<SettingViewModel>();
    final modelId = settingViewModel.sentinelMetadataGenerationModelId.value;
    if (modelId.isNotEmpty) return modelId;
    final modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.dismiss();
      AthenaDialog.warning('No enabled models found');
      return null;
    }
    return modelViewModel.enabledModels.value.first.id!;
  }
}
