import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/provider_entity.dart';
import 'package:athena/page/mobile/chat/component/model_selector.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class MobileDefaultModelFormPage extends StatefulWidget {
  const MobileDefaultModelFormPage({super.key});

  @override
  State<MobileDefaultModelFormPage> createState() =>
      _MobileDefaultModelFormPageState();
}

class _MobileDefaultModelFormPageState
    extends State<MobileDefaultModelFormPage> {
  final settingViewModel = GetIt.instance<SettingViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();

  @override
  Widget build(BuildContext context) {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var chatTitle = Text('Default Chat Model', style: titleTextStyle);
    var namingTitle = Text('Chat Naming Model', style: titleTextStyle);
    var chatSearchDecisionTitle = Text(
      'Chat Search Decision Model',
      style: titleTextStyle,
    );
    var generationTitle = Text(
      'Sentinel Metadata Generation Model',
      style: titleTextStyle,
    );
    var shortcutTitle = Text('Shortcut Model', style: titleTextStyle);
    var tipTextStyle = TextStyle(
      color: ColorUtil.FFC2C2C2,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    var chatTip = Text('Model designated for new chat', style: tipTextStyle);
    var namingTip = Text(
      'Model designated for automatic chat renaming',
      style: tipTextStyle,
    );
    var chatSearchDecisionTip = Text(
      'Model designated for deciding whether user\'s input should search from internet or not',
      style: tipTextStyle,
    );
    var generationTip = Text(
      'Model designated for generating sentinel name, description, avatar, and tags',
      style: tipTextStyle,
    );
    var shortcutTip = Text(
      'Model designated for all shortcuts',
      style: tipTextStyle,
    );
    return Watch((context) {
      var chatDropdown = _ModelDropdown(
        groupedModels: modelViewModel.groupedEnabledModels.value,
        model: settingViewModel.chatModel.value,
        onChanged: settingViewModel.updateChatModelId,
        provider: settingViewModel.chatModelProvider.value,
      );
      var chatNamingDropdown = _ModelDropdown(
        groupedModels: modelViewModel.groupedEnabledModels.value,
        model: settingViewModel.chatNamingModel.value,
        onChanged: settingViewModel.updateChatNamingModelId,
        provider: settingViewModel.chatNamingModelProvider.value,
      );
      var chatSearchDecisionDropdown = _ModelDropdown(
        groupedModels: modelViewModel.groupedEnabledModels.value,
        model: settingViewModel.chatSearchDecisionModel.value,
        onChanged: settingViewModel.updateChatSearchDecisionModelId,
        provider: settingViewModel.chatSearchDecisionModelProvider.value,
      );
      var sentinelMetadataGenerationDropdown = _ModelDropdown(
        groupedModels: modelViewModel.groupedEnabledModels.value,
        model: settingViewModel.sentinelMetadataGenerationModel.value,
        onChanged: settingViewModel.updateSentinelMetadataGenerationModelId,
        provider:
            settingViewModel.sentinelMetadataGenerationModelProvider.value,
      );
      var shortcutDropdown = _ModelDropdown(
        groupedModels: modelViewModel.groupedEnabledModels.value,
        model: settingViewModel.shortModel.value,
        onChanged: settingViewModel.updateShortModelId,
        provider: settingViewModel.shortModelProvider.value,
      );
      var listChildren = [
        chatTitle,
        const SizedBox(height: 12),
        chatDropdown,
        const SizedBox(height: 12),
        chatTip,
        const SizedBox(height: 16),
        namingTitle,
        const SizedBox(height: 12),
        chatNamingDropdown,
        const SizedBox(height: 12),
        namingTip,
        const SizedBox(height: 16),
        chatSearchDecisionTitle,
        const SizedBox(height: 12),
        chatSearchDecisionDropdown,
        const SizedBox(height: 12),
        chatSearchDecisionTip,
        const SizedBox(height: 16),
        generationTitle,
        const SizedBox(height: 12),
        sentinelMetadataGenerationDropdown,
        const SizedBox(height: 12),
        generationTip,
        const SizedBox(height: 16),
        shortcutTitle,
        const SizedBox(height: 12),
        shortcutDropdown,
        const SizedBox(height: 12),
        shortcutTip,
        SafeArea(top: false, child: const SizedBox()),
      ];
      var listView = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: listChildren,
      );
      return AthenaScaffold(
        appBar: AthenaAppBar(title: Text('Default Model')),
        body: listView,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    settingViewModel.initSignals();
    modelViewModel.initSignals();
  }
}

class _ModelDropdown extends StatelessWidget {
  final Map<String, List<ModelEntity>>? groupedModels;
  final ModelEntity? model;
  final void Function(int)? onChanged;
  final ProviderEntity? provider;
  const _ModelDropdown({
    this.groupedModels,
    this.model,
    this.onChanged,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    var boxDecoration = BoxDecoration(
      color: ColorUtil.FFADADAD.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(24),
    );
    var icon = Icon(
      HugeIcons.strokeRoundedFilterHorizontal,
      color: ColorUtil.FFF5F5F5,
      size: 20,
    );
    var children = [_buildText(), icon];
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
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

  void handleTap(ModelEntity model) {
    AthenaDialog.dismiss();
    onChanged?.call(model.id!);
  }

  void showModelSelectorDialog() {
    if (groupedModels == null) return;
    AthenaDialog.show(
      MobileModelSelectDialog(groupedModels: groupedModels!, onTap: handleTap),
      barrierDismissible: true,
    );
  }

  Widget _buildText() {
    return Watch((context) {
      const textStyle = TextStyle(
        color: ColorUtil.FFF5F5F5,
        fontSize: 14,
        height: 1.7,
      );
      if (model == null) return Text('No Model', style: textStyle);
      return Text('${model?.name} | ${provider?.name}', style: textStyle);
    });
  }
}
