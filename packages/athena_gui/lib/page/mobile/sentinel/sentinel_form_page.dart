import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_tokens.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_field.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
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

  @override
  Widget build(BuildContext context) {
    final isPreset = widget.sentinel?.isPreset ?? false;
    final colors = context.athenaColors;
    final listViewChildren = [
      if (isPreset)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'The built-in Sentinel can be read but not edited.',
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
    ];
    final listView = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    final columnChildren = [
      Expanded(child: listView),
      if (!isPreset) _buildButtons(context),
    ];
    final column = Column(children: columnChildren);
    return AthenaScaffold(
      appBar: AthenaAppBar(
        title: Text(widget.sentinel?.name ?? 'New Sentinel'),
      ),
      body: SafeArea(top: false, child: column),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final children = [
      Expanded(child: _buildStoreButton(context)),
      const SizedBox(width: 8),
      Expanded(child: _buildGenerateButton(context)),
    ];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(children: children),
    );
  }

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
