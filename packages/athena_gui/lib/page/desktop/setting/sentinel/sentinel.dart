import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/component/sentinel_context_menu.dart';
import 'package:athena_gui/page/desktop/setting/sentinel/component/sentinel_form_dialog.dart';
import 'package:athena_core/service/model_resolver.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/util/desktop_list_selection.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';
import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:athena_gui/widget/context_menu.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/form_tile_label.dart';
import 'package:athena_gui/widget/input.dart';
import 'package:athena_gui/widget/menu.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hugeicons/hugeicons.dart';
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
  final _selection = DesktopListSelection<int>();
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
    return Row(children: children);
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

  void _handleSentinelTap(int tappedIndex) {
    final sentinels = viewModel.sentinels.value;
    final sentinel = sentinels[tappedIndex];
    final activate = _selection.handleTap(
      sentinel.id,
      ids: sentinels
          .where((item) => !item.isPreset && item.id != null)
          .map((item) => item.id!)
          .toList(),
      activeId: sentinels[index].id,
    );
    if (activate) {
      changeSentinel(tappedIndex);
    } else {
      setState(() {});
    }
  }

  Future<void> destroySentinels(List<SentinelEntity> targets) async {
    final deletable = targets
        .where((item) => !item.isPreset && item.id != null)
        .toList();
    if (deletable.isEmpty) return;
    final confirmed = await AthenaDialog.confirm(
      deletable.length == 1
          ? 'Do you want to delete this sentinel?'
          : 'Do you want to delete ${deletable.length} sentinels?',
    );
    if (confirmed == true) {
      for (final sentinel in deletable) {
        final before = viewModel.sentinels.value;
        final deletedIndex = before.indexWhere(
          (item) => item.id == sentinel.id,
        );
        final activeId = index < before.length ? before[index].id : null;
        await viewModel.deleteSentinel(sentinel);
        final remaining = viewModel.sentinels.value;
        if (remaining.any((item) => item.id == sentinel.id)) {
          if (mounted) {
            AthenaDialog.error(
              viewModel.error.value ?? 'Failed to delete sentinel',
            );
          }
          break;
        }
        if (!mounted) continue;
        if (remaining.isEmpty) {
          setState(() => index = 0);
          continue;
        }
        var nextIndex = remaining.indexWhere((item) => item.id == activeId);
        if (nextIndex < 0) {
          nextIndex = (deletedIndex - 1).clamp(0, remaining.length - 1);
        }
        await changeSentinel(nextIndex);
      }
    }
    if (mounted) setState(_selection.clear);
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
    if (viewModel.isGenerating.value) return;
    if (promptController.text.trim().isEmpty) {
      AthenaDialog.warning('Prompt is required');
      return;
    }
    // 与移动端一致：生成期间显示 loading 弹窗，避免请求慢时
    // 页面看起来「没反应」（按钮旁的小 spinner 不易察觉）
    AthenaDialog.loading();
    try {
      var modelId = await _getModelId();
      if (modelId == null) return;
      final generatedSentinel = await viewModel.generateSentinel(
        promptController.text,
        modelId: modelId,
      );
      if (generatedSentinel != null) {
        // 名字由 ValueListenableBuilder 直连 controller 自动刷新，
        // 其余字段是 TextField（controller 驱动），无需 setState
        nameController.text = generatedSentinel.name;
        avatarController.text = generatedSentinel.avatar;
        descriptionController.text = generatedSentinel.description;
        tagsController.text = generatedSentinel.tags;
      } else {
        AthenaDialog.error(viewModel.error.value ?? 'Generation failed');
      }
    } catch (error) {
      AthenaDialog.error(error.toString());
    } finally {
      AthenaDialog.dismiss();
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
    if (sentinel.isPreset) return;
    final selected = viewModel.sentinels.value
        .where((item) => _selection.selectedIds.contains(item.id))
        .toList();
    final multiSelect = selected.length > 1;
    var contextMenu = DesktopSentinelContextMenu(
      multiSelect: multiSelect,
      offset: details.globalPosition - Offset(240, 50),
      onDestroyed: () => destroySentinels(multiSelect ? selected : [sentinel]),
      onEdited: () => openSentinelFormDialog(sentinel),
    );
    DesktopContextMenuManager.instance.show(context, contextMenu);
  }

  void storeSentinel() async {
    if (promptController.text.isEmpty) {
      AthenaDialog.warning('Prompt is required');
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
    AthenaDialog.success('Sentinel updated');
  }

  Widget _buildButtons(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var indicator = CircularProgressIndicator(
      color: colors.textPrimary,
      strokeWidth: 2,
    );
    var generateChildren = [
      if (viewModel.isGenerating.value)
        SizedBox(height: 16, width: 16, child: indicator),
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
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var sentinels = viewModel.sentinels.value;
      var borderSide = BorderSide(color: colors.border);
      Widget child = ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) =>
            _buildSentinelTile(context, sentinels, index),
        itemCount: sentinels.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
      if (sentinels.isEmpty) {
        var textStyle = TextStyle(
          color: colors.textPrimary,
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

  Widget _buildSentinelTile(
    BuildContext context,
    List<SentinelEntity> sentinels,
    int index,
  ) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var sentinel = sentinels[index];
    // 尾随图标跟随行文字色:选中行提亮到 textPrimary,未选中用 iconSecondary。
    // 选中行底色是 surfaceSelected(深色下比画布亮一档),两者都有足够对比。
    final selected =
        this.index == index || _selection.selectedIds.contains(sentinel.id);
    var trailingColor = selected ? colors.textPrimary : colors.iconSecondary;
    var trailing = sentinel.isPreset
        ? Icon(
            HugeIcons.strokeRoundedCircleLock01,
            size: 10,
            color: trailingColor,
          )
        : null;
    return DesktopMenuTile(
      active: selected,
      label: sentinel.name,
      trailing: trailing,
      onSecondaryTap: (details) => showSentinelContextMenu(details, sentinel),
      onTap: () => _handleSentinelTap(index),
    );
  }

  Widget _buildSentinelView() {
    return Watch((context) {
      final colors = Theme.of(context).extension<AthenaColors>()!;
      var sentinels = viewModel.sentinels.value;
      if (sentinels.isEmpty) return const SizedBox();
      var nameTextStyle = TextStyle(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      );
      var isPreset = index < sentinels.length && sentinels[index].isPreset;
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
        // 名字不监听 controller 的 Widget 不会自动刷新；
        // 用 ValueListenableBuilder 直连 controller，controller 一变即更新
        ValueListenableBuilder(
          valueListenable: nameController,
          builder: (context, value, _) =>
              Text(value.text, style: nameTextStyle),
        ),
        const SizedBox(height: 12),
        if (!isPreset) Row(children: avatarChildren),
        if (!isPreset) const SizedBox(height: 12),
        Row(children: descriptionChildren),
        const SizedBox(height: 12),
        Row(children: tagsChildren),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: promptChildren,
        ),
        const SizedBox(height: 12),
        if (!isPreset) _buildButtons(context),
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
    final settingViewModel = GetIt.instance<SettingViewModel>();
    final modelResolver = GetIt.instance<ModelResolver>();
    final model = await modelResolver.resolveModel(
      preferredModelId:
          settingViewModel.sentinelMetadataGenerationModelId.value,
    );
    if (model == null) {
      AthenaDialog.warning('No enabled models found');
      return null;
    }
    return model.id!;
  }
}
