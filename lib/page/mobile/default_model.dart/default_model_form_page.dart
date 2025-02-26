import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/setting.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileDefaultModelFormPage extends ConsumerStatefulWidget {
  const MobileDefaultModelFormPage({super.key});

  @override
  ConsumerState<MobileDefaultModelFormPage> createState() =>
      _MobileDefaultModelFormPageState();
}

class _MobileDefaultModelFormPageState
    extends ConsumerState<MobileDefaultModelFormPage> {
  late final viewModel = SettingViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var titleTextStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var chatTitle = Text('Default Chat Model', style: titleTextStyle);
    var namingTitle = Text('Chat Naming Model', style: titleTextStyle);
    var chatSearchDecisionTitle =
        Text('Chat Search Decision Model', style: titleTextStyle);
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
    var chatSearchDecisionModel =
        ref.watch(chatSearchDecisionModelNotifierProvider).valueOrNull;
    var chatSearchDecisionDropdown = _ModelDropdown(
      model: chatSearchDecisionModel,
      onChanged: viewModel.updateChatSearchDecisionModel,
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
    ];
    var listView = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: listChildren,
    );
    return AScaffold(
      appBar: AAppBar(title: Text('Default Model')),
      body: listView,
    );
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
    var children = [_buildText(ref), icon];
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

  void handleTap(Model model) {
    ADialog.dismiss();
    onChanged?.call(model);
  }

  void showModelSelectorDialog() {
    ADialog.show(
      MobileModelSelectDialog(onTap: handleTap),
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
    return Text('$modelName | $providerName', style: textStyle);
  }
}
