import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/desktop/setting/sentinel/component/sentinel_context_menu.dart';
import 'package:athena/page/desktop/setting/sentinel/component/sentinel_form_dialog.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/button.dart';
import 'package:athena/widget/context_menu.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/form_tile_label.dart';
import 'package:athena/widget/input.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopSettingSentinelPage extends StatefulWidget {
  const DesktopSettingSentinelPage({super.key});

  @override
  State<DesktopSettingSentinelPage> createState() =>
      _DesktopSettingSentinelPageState();
}

class _DesktopSettingSentinelPageState
    extends State<DesktopSettingSentinelPage> {
  int index = 0;
  bool loading = false;
  final nameController = TextEditingController();
  final avatarController = TextEditingController();
  final descriptionController = TextEditingController();
  final tagsController = TextEditingController();
  final promptController = TextEditingController();

  late final viewModel = GetIt.instance<SentinelViewModel>();

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildSentinelListView(),
      Expanded(child: _buildSentinelView()),
    ];
    return AthenaScaffold(body: Row(children: children));
  }

  Future<void> changeSentinel(int index) async {
    setState(() {
      this.index = index;
    });
    var sentinels = viewModel.sentinels.value;
    if (sentinels.isEmpty) return;
    nameController.text = sentinels[index].name;
    avatarController.text = sentinels[index].avatar;
    descriptionController.text = sentinels[index].description;
    tagsController.text = sentinels[index].tags;
    promptController.text = sentinels[index].prompt;
  }

  Future<void> destroySentinel(SentinelEntity sentinel) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete this sentinel?',
    );
    if (result == true) {
      await viewModel.deleteSentinel(sentinel);
      setState(() {
        index = 0;
      });
      var sentinels = viewModel.sentinels.value;
      if (sentinels.isEmpty) return;
      nameController.text = sentinels[index].name;
      avatarController.text = sentinels[index].avatar;
      descriptionController.text = sentinels[index].description;
      tagsController.text = sentinels[index].tags;
      promptController.text = sentinels[index].prompt;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    avatarController.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    promptController.dispose();
    super.dispose();
  }

  void generateSentinel() async {
    if (loading) return;
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.message('Prompt is required');
      return;
    }
    setState(() {
      loading = true;
    });
    try {
      var modelId = await _getModelId();
      if (modelId == null) return;
      final generatedSentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (generatedSentinel != null && nameController.text != 'Athena') {
        nameController.text = generatedSentinel.name;
        avatarController.text = generatedSentinel.avatar;
        descriptionController.text = generatedSentinel.description;
        tagsController.text = generatedSentinel.tags;
      } else if (generatedSentinel == null) {
        AthenaDialog.message(viewModel.error.value ?? 'Generation failed');
      }
      setState(() {
        loading = false;
      });
    } catch (error) {
      setState(() {
        loading = false;
      });
      AthenaDialog.message(error.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void openSentinelFormDialog(SentinelEntity sentinel) async {
    AthenaDialog.show(DesktopSentinelFormDialog(sentinel: sentinel));
  }

  void showSentinelContextMenu(TapUpDetails details, SentinelEntity sentinel) {
    if (sentinel.name == 'Athena') return;
    var contextMenu = DesktopSentinelContextMenu(
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroySentinel(sentinel),
      onEdited: () => openSentinelFormDialog(sentinel),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void storeSentinel() async {
    if (promptController.text.isEmpty) {
      AthenaDialog.message('Prompt is required');
      return;
    }
    var sentinels = viewModel.sentinels.value;
    if (sentinels.isEmpty) return;
    var copiedSentinel = sentinels[index].copyWith(
      avatar: avatarController.text,
      description: descriptionController.text,
      name: nameController.text,
      prompt: promptController.text,
      tags: tagsController.text,
    );
    await viewModel.updateSentinel(copiedSentinel);
    AthenaDialog.message('Sentinel updated');
  }

  Widget _buildButtons() {
    var indicator = CircularProgressIndicator(
      color: ColorUtil.FFFFFFFF,
      strokeWidth: 2,
    );
    var generateChildren = [
      if (loading) SizedBox(height: 16, width: 16, child: indicator),
      AthenaTextButton(text: 'Generate', onTap: generateSentinel),
    ];
    var generateButton = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: generateChildren,
    );
    const edgeInsets = EdgeInsets.symmetric(horizontal: 16);
    final storeButton = AthenaPrimaryButton(
      onTap: storeSentinel,
      child: Padding(padding: edgeInsets, child: const Text('Store')),
    );
    final children = [generateButton, const SizedBox(width: 12), storeButton];
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: children);
  }

  Widget _buildSentinelListView() {
    return Watch((context) {
      var sentinels = viewModel.sentinels.value;
      var borderSide = BorderSide(
        color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
      );
      Widget child = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) => _buildSentinelTile(sentinels, index),
        itemCount: sentinels.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      if (sentinels.isEmpty) {
        var textStyle = TextStyle(
          color: ColorUtil.FFFFFFFF,
          decoration: TextDecoration.none,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        );
        child = Center(child: Text('No Sentinels', style: textStyle));
      }
      return Container(
        decoration: BoxDecoration(border: Border(right: borderSide)),
        width: 240,
        child: child,
      );
    });
  }

  Widget _buildSentinelTile(List<SentinelEntity> sentinels, int index) {
    var sentinel = sentinels[index];
    return DesktopMenuTile(
      active: this.index == index,
      label: sentinel.name,
      onSecondaryTap: (details) => showSentinelContextMenu(details, sentinel),
      onTap: () => changeSentinel(index),
    );
  }

  Widget _buildSentinelView() {
    return Watch((context) {
      var sentinels = viewModel.sentinels.value;
      if (sentinels.isEmpty) return const SizedBox();
      var nameTextStyle = TextStyle(
        color: ColorUtil.FFFFFFFF,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );
      var avatarInput = AthenaInput(controller: avatarController);
      var avatarChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Avatar')),
        Expanded(child: avatarInput),
      ];
      var descriptionInput = AthenaInput(controller: descriptionController);
      var descriptionChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Description')),
        Expanded(child: descriptionInput),
      ];
      var tagsInput = AthenaInput(controller: tagsController);
      var tagsChildren = [
        SizedBox(width: 120, child: AthenaFormTileLabel(title: 'Tags')),
        Expanded(child: tagsInput),
      ];
      var promptInput = AthenaInput(
        controller: promptController,
        maxLines: 20,
        minLines: 20,
      );
      const edgeInsets = EdgeInsets.symmetric(vertical: 16);
      var promptLabel = SizedBox(
        width: 120,
        child: AthenaFormTileLabel(title: 'Prompt'),
      );
      var promptChildren = [
        Padding(padding: edgeInsets, child: promptLabel),
        Expanded(child: promptInput),
      ];
      var listChildren = [
        Text(nameController.text, style: nameTextStyle),
        const SizedBox(height: 12),
        if (nameController.text != 'Athena') Row(children: avatarChildren),
        if (nameController.text != 'Athena') const SizedBox(height: 12),
        Row(children: descriptionChildren),
        const SizedBox(height: 12),
        Row(children: tagsChildren),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: promptChildren,
        ),
        const SizedBox(height: 12),
        _buildButtons(),
      ];
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        children: listChildren,
      );
    });
  }

  Future<void> _initState() async {
    var sentinels = viewModel.sentinels.value;
    if (sentinels.isEmpty) return;
    nameController.text = sentinels[index].name;
    avatarController.text = sentinels[index].avatar;
    descriptionController.text = sentinels[index].description;
    tagsController.text = sentinels[index].tags;
    promptController.text = sentinels[index].prompt;
    setState(() {});
  }

  Future<int?> _getModelId() async {
    var settingViewModel = GetIt.instance<SettingViewModel>();
    var modelId = settingViewModel.sentinelMetadataGenerationModelId.value;
    if (modelId > 0) return modelId;
    var modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      setState(() {
        loading = false;
      });
      AthenaDialog.message('No enabled models found');
      return null;
    }
    return modelViewModel.enabledModels.value.first.id!;
  }
}
