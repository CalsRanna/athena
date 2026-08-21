import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

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
      const AthenaFormTileLabel.large(title: 'Prompt'),
      const SizedBox(height: 12),
      AthenaInput(
        controller: promptController,
        maxLines: 8,
        minLines: 8,
        enabled: !isPreset,
      ),
      const SizedBox(height: 32),
      _buildNameLabel(context),
      const SizedBox(height: 12),
      AthenaInput(controller: nameController, enabled: !isPreset),
      const SizedBox(height: 16),
      _buildDescriptionLabel(context),
      const SizedBox(height: 12),
      AthenaInput(
        controller: descriptionController,
        maxLines: 4,
        minLines: 4,
        enabled: !isPreset,
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

  Widget _buildDescriptionLabel(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: colors.textPrimary,
      size: 16,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: generateSentinelDescription,
      child: icon,
    );
    return AthenaFormTileLabel.large(
      title: 'Description',
      trailing: gestureDetector,
    );
  }

  Widget _buildGenerateButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return AthenaPrimaryButton(
      onTap: generateSentinel,
      child: Center(child: Text('Generate', style: textStyle)),
    );
  }

  Widget _buildNameLabel(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: colors.textPrimary,
      size: 16,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: generateSentinelName,
      child: icon,
    );
    return AthenaFormTileLabel.large(title: 'Name', trailing: gestureDetector);
  }

  Widget _buildStoreButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var textStyle = TextStyle(
      color: colors.textOnRaised,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return AthenaPrimaryButton(
      onTap: storeSentinel,
      child: Center(child: Text('Store', style: textStyle)),
    );
  }

  Future<void> _store() async {
    var sentinel = SentinelEntity(
      id: 0,
      name: nameController.text,
      avatar: '',
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

  Future<int?> _getModelId() async {
    var settingViewModel = GetIt.instance<SettingViewModel>();
    var modelId = settingViewModel.sentinelMetadataGenerationModelId.value;
    if (modelId > 0) return modelId;
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
