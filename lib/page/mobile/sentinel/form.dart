import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileSentinelFormPage extends StatefulWidget {
  final SentinelEntity? sentinel;
  const MobileSentinelFormPage({super.key, this.sentinel});

  @override
  State<MobileSentinelFormPage> createState() =>
      _MobileSentinelFormPageState();
}

class _MobileSentinelFormPageState extends State<MobileSentinelFormPage> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final promptController = TextEditingController();

  late final viewModel = GetIt.instance<SentinelViewModel>();

  @override
  Widget build(BuildContext context) {
    var listViewChildren = [
      const AthenaFormTileLabel.large(title: 'Prompt'),
      const SizedBox(height: 12),
      AthenaInput(controller: promptController, maxLines: 8, minLines: 8),
      const SizedBox(height: 32),
      _buildNameLabel(),
      const SizedBox(height: 12),
      AthenaInput(controller: nameController),
      const SizedBox(height: 16),
      _buildDescriptionLabel(),
      const SizedBox(height: 12),
      AthenaInput(controller: descriptionController, maxLines: 4, minLines: 4),
    ];
    var listView = ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: listViewChildren,
    );
    var columnChildren = [
      Expanded(child: listView),
      _buildButtons(),
    ];
    var column = Column(children: columnChildren);
    return AthenaScaffold(
      appBar:
          AthenaAppBar(title: Text(widget.sentinel?.name ?? 'New Sentinel')),
      body: SafeArea(top: false, child: column),
    );
  }

  Widget _buildButtons() {
    var children = [
      Expanded(child: _buildStoreButton()),
      const SizedBox(width: 8),
      Expanded(child: _buildGenerateButton()),
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
      AthenaDialog.message('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      var modelViewModel = GetIt.instance<ModelViewModel>();
      await modelViewModel.loadEnabledModels();
      if (modelViewModel.enabledModels.value.isEmpty) {
        AthenaDialog.dismiss();
        AthenaDialog.message('No enabled models found');
        return;
      }
      var modelId = modelViewModel.enabledModels.value.first.id!;
      var sentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (sentinel != null) {
        nameController.text = sentinel.name;
        descriptionController.text = sentinel.description;
      }
      AthenaDialog.dismiss();
    } catch (error) {
      AthenaDialog.dismiss();
      AthenaDialog.message(error.toString());
    }
  }

  Future<void> generateSentinelDescription() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.message('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      var modelViewModel = GetIt.instance<ModelViewModel>();
      await modelViewModel.loadEnabledModels();
      if (modelViewModel.enabledModels.value.isEmpty) {
        AthenaDialog.dismiss();
        AthenaDialog.message('No enabled models found');
        return;
      }
      var modelId = modelViewModel.enabledModels.value.first.id!;
      var sentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (sentinel != null) {
        descriptionController.text = sentinel.description;
      }
      AthenaDialog.dismiss();
    } catch (error) {
      AthenaDialog.dismiss();
      AthenaDialog.message(error.toString());
    }
  }

  Future<void> generateSentinelName() async {
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.message('Prompt is required');
      return;
    }
    AthenaDialog.loading();
    try {
      var modelViewModel = GetIt.instance<ModelViewModel>();
      await modelViewModel.loadEnabledModels();
      if (modelViewModel.enabledModels.value.isEmpty) {
        AthenaDialog.dismiss();
        AthenaDialog.message('No enabled models found');
        return;
      }
      var modelId = modelViewModel.enabledModels.value.first.id!;
      var sentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (sentinel != null) {
        nameController.text = sentinel.name;
      }
      AthenaDialog.dismiss();
    } catch (error) {
      AthenaDialog.dismiss();
      AthenaDialog.message(error.toString());
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
    if (message != null) return AthenaDialog.message(message);
    if (widget.sentinel == null) return _store();
    _update();
  }

  Widget _buildDescriptionLabel() {
    const icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: ColorUtil.FFFFFFFF,
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

  Widget _buildGenerateButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return AthenaPrimaryButton(
      onTap: generateSentinel,
      child: Center(child: Text('Generate', style: textStyle)),
    );
  }

  Widget _buildNameLabel() {
    const icon = Icon(
      HugeIcons.strokeRoundedAiBeautify,
      color: ColorUtil.FFFFFFFF,
      size: 16,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: generateSentinelName,
      child: icon,
    );
    return AthenaFormTileLabel.large(title: 'Name', trailing: gestureDetector);
  }

  Widget _buildStoreButton() {
    var textStyle = TextStyle(
      color: ColorUtil.FF161616,
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
      tags: [],
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
}
