import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
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
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  late final viewModel = GetIt.instance<SentinelViewModel>();

  @override
  Widget build(BuildContext context) {
    var isPreset = widget.sentinel?.isPreset ?? false;
    var listViewChildren = [
      AthenaFormField(
        label: 'Prompt',
        control: AthenaInput(
          controller: promptController,
          maxLines: 8,
          minLines: 8,
        ),
      ),
      const SizedBox(height: 32),
      AthenaFormField(
        label: 'Name',
        control: AthenaInput(controller: nameController),
        trailing: _buildGenerateIcon(generateSentinelName),
      ),
      const SizedBox(height: 16),
      AthenaFormField(
        label: 'Description',
        control: AthenaInput(
          controller: descriptionController,
          maxLines: 4,
          minLines: 4,
        ),
        trailing: _buildGenerateIcon(generateSentinelDescription),
      ),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [
      Expanded(child: listView),
      if (!isPreset) _buildButtons(context),
    ];
    var column = Column(children: columnChildren);
    return AthenaScaffold(
      appBar: AthenaAppBar(
        title: Text(widget.sentinel?.name ?? 'New Sentinel'),
      ),
      body: SafeArea(top: false, child: column),
    );
  }

  Widget _buildButtons(BuildContext context) {
    var children = [
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
    super.dispose();
  }

  Future<void> generateSentinel() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.warning('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      var modelId = await _getModelId();
      if (modelId == null) return;
      var sentinel = await viewModel.generateSentinel(
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
      var modelId = await _getModelId();
      if (modelId == null) return;
      var description = await viewModel.generateSentinelDescription(
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
      var modelId = await _getModelId();
      if (modelId == null) return;
      var name = await viewModel.generateSentinelName(
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
  }

  Future<void> storeSentinel() async {
    var message = _validate();
    if (message != null) return AthenaDialog.warning(message);
    if (widget.sentinel == null) return _store();
    _update();
  }

  /// 标签行右端的「生成」星标，点一下让模型填这个字段。
  Widget _buildGenerateIcon(VoidCallback onTap) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
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
      child: Center(child: Text('Generate')),
    );
  }

  Widget _buildStoreButton(BuildContext context) {
    return AthenaPrimaryButton(
      onTap: storeSentinel,
      child: Center(child: Text('Store')),
    );
  }

  Future<void> _store() async {
    var sentinel = SentinelEntity(
      name: nameController.text,
      description: descriptionController.text,
      tags: '',
      prompt: promptController.text,
    );
    await viewModel.createSentinel(sentinel);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  Future<void> _update() async {
    var sentinel = widget.sentinel!.copyWith(
      name: nameController.text,
      description: descriptionController.text,
      prompt: promptController.text,
    );
    await viewModel.updateSentinel(sentinel);
    if (!mounted) return;
    AutoRouter.of(context).maybePop();
  }

  String? _validate() {
    if (nameController.text.isEmpty) return 'Name is required';
    if (descriptionController.text.isEmpty) return 'Description is required';
    if (promptController.text.isEmpty) return 'Prompt is required';
    return null;
  }

  Future<String?> _getModelId() async {
    var settingViewModel = GetIt.instance<SettingViewModel>();
    var modelId = settingViewModel.sentinelMetadataGenerationModelId.value;
    if (modelId.isNotEmpty) return modelId;
    var modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.dismiss();
      AthenaDialog.warning('No enabled models found');
      return null;
    }
    return modelViewModel.enabledModels.value.first.id!;
  }
}
