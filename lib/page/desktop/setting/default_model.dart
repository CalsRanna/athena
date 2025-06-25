import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/menu.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopSettingDefaultModelPage extends ConsumerStatefulWidget {
  const DesktopSettingDefaultModelPage({super.key});

  @override
  ConsumerState<DesktopSettingDefaultModelPage> createState() =>
      _DesktopSettingDefaultModelPageState();
}

class _DesktopSettingDefaultModelPageState
    extends ConsumerState<DesktopSettingDefaultModelPage> {
  late final viewModel = SettingViewModel(ref);
  int index = 0;

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildDefaultModelListView(),
      Expanded(child: _buildDefaultModelView()),
    ];
    return AthenaScaffold(body: Row(children: children));
  }

  Future<void> changeDefaultModel(int index) async {
    setState(() {
      this.index = index;
    });
  }

  Widget _buildDefaultModelListView() {
    var models = [
      'Chat',
      'Topic Naming',
      'Sentinel Metadata Generation',
    ];
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    Widget child = ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) => _buildDefaultModelTile(models, index),
      itemCount: models.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
    return Container(
      decoration: BoxDecoration(border: Border(right: borderSide)),
      width: 240,
      child: child,
    );
  }

  Widget _buildDefaultModelTile(List<String> models, int index) {
    var model = models[index];
    return DesktopMenuTile(
      active: this.index == index,
      label: model,
      onTap: () => changeDefaultModel(index),
    );
  }

  Widget _buildDefaultModelView() {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var chatTitle = Text('Chat Model', style: titleTextStyle);
    var namingTitle = Text('Topic Naming Model', style: titleTextStyle);
    var generationTitle = Text(
      'Sentinel Metadata Generation Model',
      style: titleTextStyle,
    );
    var chatModel = ref.watch(chatModelNotifierProvider).valueOrNull;
    var chatDropdown = _ModelDropdown(
      model: chatModel,
      onChanged: viewModel.updateChatModel,
    );
    var chatNamingModel =
        ref.watch(chatNamingModelNotifierProvider).valueOrNull;
    var chatNamingDropdown = _ModelDropdown(
      model: chatNamingModel,
      onChanged: viewModel.updateChatNamingModel,
    );
    var provider = sentinelMetaGenerationModelNotifierProvider;
    var sentinelMetadataGenerationModel = ref.watch(provider).valueOrNull;
    var sentinelMetadataGenerationDropdown = _ModelDropdown(
      model: sentinelMetadataGenerationModel,
      onChanged: viewModel.updateSentinelMetaGenerationModel,
    );
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var chatTip = Text('Model designated for new chat', style: tipTextStyle);
    var namingTip = Text(
      'Model designated for automatic naming topic',
      style: tipTextStyle,
    );
    var generationTip = Text(
      'Model designated for generating sentinel name, description, avatar, and tags',
      style: tipTextStyle,
    );
    var edgeInsets = EdgeInsets.symmetric(horizontal: 32, vertical: 12);
    return switch (index) {
      0 => ListView(
          padding: edgeInsets,
          children: [
            chatTitle,
            const SizedBox(height: 12),
            chatDropdown,
            const SizedBox(height: 12),
            chatTip,
          ],
        ),
      1 => ListView(
          padding: edgeInsets,
          children: [
            namingTitle,
            const SizedBox(height: 12),
            chatNamingDropdown,
            const SizedBox(height: 12),
            namingTip,
            const SizedBox(height: 24),
          ],
        ),
      2 => ListView(
          padding: edgeInsets,
          children: [
            generationTitle,
            const SizedBox(height: 12),
            sentinelMetadataGenerationDropdown,
            const SizedBox(height: 12),
            generationTip,
            const SizedBox(height: 24),
          ],
        ),
      _ => const SizedBox(),
    };
  }
}

class _ModelDropdown extends ConsumerWidget {
  final Model? model;
  final void Function(Model)? onChanged;
  const _ModelDropdown({this.model, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(24),
    );
    var icon = Icon(
      HugeIcons.strokeRoundedFilterHorizontal,
      color: ColorUtil.FFF5F5F5,
      size: 20,
    );
    var children = [Expanded(child: _buildText(ref)), icon];
    var row = Row(children: children);
    var container = Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15.5),
      child: row,
    );
    var mouseRegion = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: container,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: showModelSelectorDialog,
      child: mouseRegion,
    );
  }

  void handleTap(Model model) {
    AthenaDialog.dismiss();
    onChanged?.call(model);
  }

  void showModelSelectorDialog() {
    AthenaDialog.show(
      DesktopModelSelectDialog(onTap: handleTap),
      barrierDismissible: true,
    );
  }

  Widget _buildText(WidgetRef ref) {
    const textStyle = TextStyle(
      color: ColorUtil.FFF5F5F5,
      fontSize: 14,
      height: 1.7,
    );
    if (model == null) return Text('No Model', style: textStyle);
    if (model!.name.isEmpty) return Text('No Model', style: textStyle);
    var modelName = model!.name;
    var provider = providerNotifierProvider(model!.providerId);
    var aiProvider = ref.watch(provider).valueOrNull;
    var providerName = aiProvider?.name ?? '';
    if (providerName.isEmpty) return Text(modelName, style: textStyle);
    return Text(
      '$modelName | $providerName',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}
