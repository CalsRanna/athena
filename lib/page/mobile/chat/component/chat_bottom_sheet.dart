import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/mobile/chat/component/chat_configuration_dialog.dart';
import 'package:athena/page/mobile/chat/component/model_selector.dart';
import 'package:athena/page/mobile/chat/component/sentinel_selector.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/view_model/provider_view_model.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

class MobileChatBottomSheet extends StatefulWidget {
  final ChatEntity chat;
  final void Function(int)? onContextChanged;
  final void Function(bool)? onEnableSearchChanged;
  final void Function(ModelEntity)? onModelChanged;
  final void Function(SentinelEntity)? onSentinelChanged;
  final void Function(double)? onTemperatureChanged;
  const MobileChatBottomSheet({
    super.key,
    required this.chat,
    this.onContextChanged,
    this.onEnableSearchChanged,
    this.onModelChanged,
    this.onSentinelChanged,
    this.onTemperatureChanged,
  });

  @override
  State<MobileChatBottomSheet> createState() => _MobileChatBottomSheetState();
}

class _MobileChatBottomSheetState extends State<MobileChatBottomSheet> {
  late final chatViewModel = GetIt.instance<ChatViewModel>();
  late final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  late final modelViewModel = GetIt.instance<ModelViewModel>();
  late final providerViewModel = GetIt.instance<ProviderViewModel>();

  late int sentinelId = widget.chat.sentinelId;
  late int modelId = widget.chat.modelId;
  late bool enableSearch = widget.chat.enableSearch;
  late double temperature = widget.chat.temperature;
  late int contextToken = widget.chat.context;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var sentinel = sentinelViewModel.sentinels.value
          .where((s) => s.id == sentinelId)
          .firstOrNull;
      var model = modelViewModel.models.value
          .where((m) => m.id == modelId)
          .firstOrNull;
      var provider = providerViewModel.providers.value
          .where((p) => p.id == (model?.providerId ?? 0))
          .firstOrNull;

      var modelName = model?.name ?? '';
      var providerName = provider?.name ?? '';
      var modelFullName =
          '$modelName${providerName.isNotEmpty ? ' | $providerName' : ''}';
      var sentinelSheetTile = AthenaBottomSheetTile(
        leading: Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
        onTap: openSentinelSelectorDialog,
        title: 'Sentinel',
        trailing: Text(sentinel?.name ?? ''),
      );
      var modelSheetTile = AthenaBottomSheetTile(
        leading: Icon(HugeIcons.strokeRoundedAiBrain01),
        onTap: openModelSelectorDialog,
        title: 'Model',
        trailing: Text(modelFullName),
      );
      var athenaSwitch = AthenaSwitch(
        onChanged: _updateEnableSearch,
        value: enableSearch,
      );
      var searchDecisionSheetTile = AthenaBottomSheetTile(
        leading: Icon(HugeIcons.strokeRoundedInternet),
        onTap: () => _updateEnableSearch(!enableSearch),
        title: 'Search Decision',
        trailing: athenaSwitch,
      );
      var chatConfigurationSheetTile = AthenaBottomSheetTile(
        leading: Icon(HugeIcons.strokeRoundedSlidersHorizontal),
        onTap: openConfigurationDialog,
        title: 'Chat Configuration',
        trailing: Icon(HugeIcons.strokeRoundedArrowRight02),
      );
      var exportImageSheetTile = AthenaBottomSheetTile(
        leading: Icon(HugeIcons.strokeRoundedFileExport),
        onTap: navigateImageExport,
        title: 'Export Image',
        trailing: Icon(HugeIcons.strokeRoundedArrowRight02),
      );
      var children = [
        sentinelSheetTile,
        modelSheetTile,
        searchDecisionSheetTile,
        chatConfigurationSheetTile,
        exportImageSheetTile,
      ];
      var padding = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
      return SafeArea(child: padding);
    });
  }

  void navigateImageExport() {
    AthenaDialog.dismiss();
    MobileChatExportRoute(chat: widget.chat).push(context);
  }

  void navigateChatConfiguration() {
    MobileChatConfigurationRoute(chat: widget.chat).push(context);
  }

  void openModelSelectorDialog() {
    var dialog = MobileModelSelectDialog(
      groupedModels: modelViewModel.groupedEnabledModels.value,
      onTap: _updateModel,
    );
    AthenaDialog.show(dialog);
  }

  void openConfigurationDialog() {
    var dialog = MobileChatConfigurationDialog(
      chat: widget.chat,
      contextToken: contextToken,
      temperature: temperature,
      onTemperatureChanged: _updateTemperature,
      onContextChanged: _updateContextToken,
    );
    AthenaDialog.show(dialog);
  }

  void _updateContextToken(int value) {
    widget.onContextChanged?.call(value);
    setState(() {
      contextToken = value;
    });
  }

  void _updateTemperature(double value) {
    widget.onTemperatureChanged?.call(value);
    setState(() {
      temperature = value;
    });
  }

  void openSentinelSelectorDialog() {
    var dialog = MobileSentinelSelectDialog(onTap: _updateSentinel);
    AthenaDialog.show(dialog);
  }

  void _updateEnableSearch(bool value) {
    widget.onEnableSearchChanged?.call(value);
    setState(() {
      enableSearch = value;
    });
  }

  void _updateModel(ModelEntity model) {
    widget.onModelChanged?.call(model);
    AthenaDialog.dismiss();
    setState(() {
      modelId = model.id ?? 0;
    });
  }

  void _updateSentinel(SentinelEntity sentinel) {
    widget.onSentinelChanged?.call(sentinel);
    AthenaDialog.dismiss();
    setState(() {
      sentinelId = sentinel.id ?? 0;
    });
  }
}
