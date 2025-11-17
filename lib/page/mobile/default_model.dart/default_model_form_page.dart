import 'package:athena/entity/model_entity.dart';
import 'package:athena/page/mobile/chat/component/model_selector.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/ai_provider_view_model.dart';
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
  late final viewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
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
      var shortcutTitle = Text('Shortcut Model', style: titleTextStyle);

      var chatModel = viewModel.chatModelId.value;
      var chatDropdown = _ModelDropdown(
        model: chatModel,
        onChanged: viewModel.updateChatModelId,
      );
      var chatNamingModel = viewModel.chatNamingModelId.value;
      var chatNamingDropdown = _ModelDropdown(
        model: chatNamingModel,
        onChanged: viewModel.updateChatNamingModelId,
      );
      var chatSearchDecisionModel = viewModel.chatSearchDecisionModelId.value;
      var chatSearchDecisionDropdown = _ModelDropdown(
        model: chatSearchDecisionModel,
        onChanged: viewModel.updateChatSearchDecisionModelId,
      );
      var sentinelMetadataGenerationModel =
          viewModel.sentinelMetadataGenerationModelId.value;
      var sentinelMetadataGenerationDropdown = _ModelDropdown(
        model: sentinelMetadataGenerationModel,
        onChanged: viewModel.updateSentinelMetadataGenerationModelId,
      );
      var shortcutModel = viewModel.shortModelId.value;
      var shortcutDropdown = _ModelDropdown(
        model: shortcutModel,
        onChanged: viewModel.updateShortModelId,
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
      var shortcutTip = Text(
        'Model designated for all shortcuts',
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
        const SizedBox(height: 16),
        shortcutTitle,
        const SizedBox(height: 12),
        shortcutDropdown,
        const SizedBox(height: 12),
        shortcutTip,
        SafeArea(top: false, child: const SizedBox())
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
}

class _ModelDropdown extends StatelessWidget {
  final int? model;
  final void Function(int)? onChanged;
  const _ModelDropdown({this.model, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
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
    });
  }

  void handleTap(ModelEntity model) {
    AthenaDialog.dismiss();
    onChanged?.call(model.id!);
  }

  void showModelSelectorDialog() {
    AthenaDialog.show(
      MobileModelSelectDialog(onTap: handleTap),
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
      if (model == null || model == 0) return Text('No Model', style: textStyle);

      var modelViewModel = GetIt.instance<ModelViewModel>();
      var providerViewModel = GetIt.instance<AIProviderViewModel>();
      var modelEntity = modelViewModel.models.value
          .where((m) => m.id == model)
          .firstOrNull;
      if (modelEntity == null) return Text('No Model', style: textStyle);

      var modelName = modelEntity.name;
      var aiProvider = providerViewModel.providers.value
          .where((p) => p.id == modelEntity.providerId)
          .firstOrNull;
      var providerName = aiProvider?.name ?? '';
      if (providerName.isEmpty) return Text(modelName, style: textStyle);
      return Text('$modelName | $providerName', style: textStyle);
    });
  }
}
