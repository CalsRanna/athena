import 'package:athena/page/mobile/chat/component/model_selector.dart';
import 'package:athena/page/mobile/chat/component/sentinel_selector.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/bottom_sheet_tile.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class MobileChatBottomSheet extends ConsumerStatefulWidget {
  final Chat chat;
  final void Function(bool)? onEnableSearchChanged;
  final void Function(Model)? onModelChanged;
  final void Function(Sentinel)? onSentinelChanged;
  const MobileChatBottomSheet({
    super.key,
    required this.chat,
    this.onEnableSearchChanged,
    this.onModelChanged,
    this.onSentinelChanged,
  });

  @override
  ConsumerState<MobileChatBottomSheet> createState() =>
      _MobileChatBottomSheetState();
}

class _MobileChatBottomSheetState extends ConsumerState<MobileChatBottomSheet> {
  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var sentinelProvider = sentinelNotifierProvider(widget.chat.sentinelId);
    var sentinel = ref.watch(sentinelProvider).value;
    var modelProvider = modelNotifierProvider(widget.chat.modelId);
    var model = ref.watch(modelProvider).value;
    var sentinelSheetTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedArtificialIntelligence03),
      onTap: openSentinelSelectorDialog,
      title: 'Sentinel Selector',
      trailing: Text(sentinel?.name ?? ''),
    );
    var modelSheetTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedAiBrain01),
      onTap: openModelSelectorDialog,
      title: 'Model Selector',
      trailing: Text(model?.name ?? ''),
    );
    var athenaSwitch = AthenaSwitch(
      onChanged: _updateEnableSearch,
      value: widget.chat.enableSearch,
    );
    var searchDecisionSheetTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedInternet),
      onTap: () => _updateEnableSearch(!widget.chat.enableSearch),
      title: 'Search Decision',
      trailing: athenaSwitch,
    );
    var chatConfigurationSheetTile = AthenaBottomSheetTile(
      leading: Icon(HugeIcons.strokeRoundedSlidersHorizontal),
      onTap: navigateChatConfiguration,
      title: 'Chat Configuration',
      trailing: Icon(HugeIcons.strokeRoundedArrowRight02),
    );
    var children = [
      sentinelSheetTile,
      modelSheetTile,
      searchDecisionSheetTile,
      chatConfigurationSheetTile,
    ];
    var padding = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    return SafeArea(child: padding);
  }

  void navigateChatConfiguration() {
    AthenaDialog.dismiss();
    MobileChatConfigurationRoute(chat: widget.chat).push(context);
  }

  void openModelSelectorDialog() {
    AthenaDialog.dismiss();
    var dialog = MobileModelSelectDialog(onTap: _updateModel);
    AthenaDialog.show(dialog);
  }

  void openSentinelSelectorDialog() {
    AthenaDialog.dismiss();
    var dialog = MobileSentinelSelectDialog(onTap: _updateSentinel);
    AthenaDialog.show(dialog);
  }

  void _updateEnableSearch(bool value) {
    widget.onEnableSearchChanged?.call(value);
    AthenaDialog.dismiss();
  }

  void _updateModel(Model model) {
    widget.onModelChanged?.call(model);
    AthenaDialog.dismiss();
  }

  void _updateSentinel(Sentinel sentinel) {
    widget.onSentinelChanged?.call(sentinel);
    AthenaDialog.dismiss();
  }
}
