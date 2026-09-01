import 'dart:convert';
import 'dart:io';

import 'package:athena_core/entity/chat_entity.dart';
import 'package:athena_core/entity/message_entity.dart';
import 'package:athena_core/entity/model_entity.dart';
import 'package:athena_core/entity/sentinel_entity.dart';
import 'package:athena_gui/page/desktop/home/component/chat_list.dart';
import 'package:athena_gui/page/desktop/home/component/message_input.dart';
import 'package:athena_gui/page/desktop/home/component/message_list.dart';
import 'package:athena_gui/page/desktop/home/component/model_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/model_selector.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena_gui/page/desktop/home/component/sentinel_selector.dart';

import 'package:athena_gui/router/router.gr.dart';
import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/view_model/chat_view_model.dart';
import 'package:athena_gui/view_model/model_view_model.dart';
import 'package:athena_gui/view_model/sentinel_view_model.dart';

import 'package:athena_gui/view_model/setting_view_model.dart';
import 'package:athena_gui/widget/app_bar.dart';
import 'package:athena_gui/widget/dialog.dart';
import 'package:athena_gui/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:signals_flutter/signals_flutter.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final chatViewModel = GetIt.instance<ChatViewModel>();
  final modelViewModel = GetIt.instance<ModelViewModel>();
  final sentinelViewModel = GetIt.instance<SentinelViewModel>();
  final settingViewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var children = [
        _buildLeftBar(context),
        Expanded(child: _buildWorkspace()),
      ];
      return AthenaScaffold(
        appBar: _buildAppBar(context),
        body: Row(children: children),
      );
    });
  }

  Future<void> createChat() async {
    var modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.warning('You should enable a provider first');
      return;
    }

    await chatViewModel.createChat();
  }

  Future<void> batchDestroyChats(List<ChatEntity> chats) async {
    var result = await AthenaDialog.confirm(
      'Do you want to delete ${chats.length} chats?',
    );
    if (result == true) {
      var duration = Duration(milliseconds: 300);
      if (scrollController.hasClients) {
        scrollController.animateTo(0, curve: Curves.linear, duration: duration);
      }
      await chatViewModel.deleteChats(chats);
    }
    chatViewModel.clearSelection();
  }

  Future<void> destroyChat(ChatEntity chat) async {
    var result = await AthenaDialog.confirm('Do you want to delete this chat?');
    if (result == true) {
      var duration = Duration(milliseconds: 300);
      if (scrollController.hasClients) {
        scrollController.animateTo(0, curve: Curves.linear, duration: duration);
      }
      await chatViewModel.deleteChat(chat);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> manualRenameChat(ChatEntity chat) async {
    var title = await AthenaDialog.input(
      'Rename Chat',
      initialValue: chat.title,
    );
    if (title != null && title.isNotEmpty) {
      await chatViewModel.renameChatManually(chat, title);
    }
  }

  Future<void> resendMessage(MessageEntity message) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) return;
    // 当前对话正在流式时重发会先删消息再被 sendMessage 静默吞掉，直接拦截
    if (chatViewModel.isStreamingChat(chat.id!)) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    await chatViewModel.deleteMessage(message);
    await chatViewModel.sendMessage(message, chat: chat);
  }

  Future<void> sendMessage() async {
    var text = controller.text.trim();
    if (text.isEmpty) return;

    // 检查是否有可用的模型
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.warning('You should enable a provider first');
      return;
    }

    // 如果没有选中的聊天，先创建一个
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chat = await chatViewModel.createChat();
      if (chat == null) return;
    }

    // 检查当前聊天的模型是否有效
    var model = chatViewModel.currentModel.value;
    if (model == null || model.id! <= 0) {
      AthenaDialog.warning('You should select a model first');
      return;
    }

    controller.clear();
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    var imageUrls = <String>[];
    var images = chatViewModel.pendingImages.value;
    for (var image in images) {
      var bytes = await File(image).readAsBytes();
      imageUrls.add(base64Encode(bytes));
    }

    var message = MessageEntity(
      id: 0,
      chatId: chat.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: imageUrls.join(','),
    );
    chatViewModel.clearPendingImages();

    await chatViewModel.sendMessage(message, chat: chat);
  }

  void terminateStreaming() {
    final chat = chatViewModel.currentChat.value;
    if (chat != null) chatViewModel.stopGenerating(chat.id!);
  }

  Future<void> updateRetention(int retention) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentRetention(retention);
      return;
    }
    await chatViewModel.updateRetention(retention, chat: chat);
  }

  void updateImage(List<String> images) {
    chatViewModel.pendingImages.value = images;
  }

  Future<void> updateModel(ModelEntity newModel) async {
    var chat = chatViewModel.currentChat.value;
    if (chat != null) {
      // 有选中的对话，更新对话的模型
      await chatViewModel.updateModel(newModel, chat: chat);
    } else {
      // 没有选中对话，只更新当前状态
      await chatViewModel.updateCurrentModel(newModel);
    }
  }

  Future<void> updateSentinel(SentinelEntity newSentinel) async {
    var chat = chatViewModel.currentChat.value;
    if (chat != null) {
      // 有选中的对话，更新对话的哨兵
      await chatViewModel.updateSentinel(newSentinel, chat: chat);
    } else {
      // 没有选中对话，只更新当前状态
      chatViewModel.updateCurrentSentinel(newSentinel);
    }
  }

  Future<void> updateTemperature(double temperature) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentTemperature(temperature);
      return;
    }
    await chatViewModel.updateTemperature(temperature, chat: chat);
  }

  Future<void> updateReasoningEffort(String? effort) async {
    var chat = chatViewModel.currentChat.value;
    if (chat == null) {
      chatViewModel.updateCurrentReasoningEffort(effort);
      return;
    }
    await chatViewModel.updateReasoningEffort(effort, chat: chat);
  }

  Widget _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: colors.textPrimary,
      size: 24,
    );
    var chatCreateButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
    return AthenaAppBar(
      action: _buildSettingButton(context),
      leading: Align(alignment: Alignment.centerRight, child: chatCreateButton),
      title: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                DesktopSentinelIndicator(onTap: _openSentinelSelector),
                DesktopModelIndicator(onTap: _openModelSelector),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftBar(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    var chatListView = DesktopChatListView(
      onAutoRenamed: chatViewModel.renameChat,
      onBatchDestroyed: batchDestroyChats,
      onDestroyed: destroyChat,
      onManualRenamed: manualRenameChat,
      onPinned: chatViewModel.togglePin,
      onSelected: chatViewModel.selectChat,
    );
    var borderSide = BorderSide(
      color: colors.borderFaint.withValues(alpha: 0.2),
    );
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      width: 240,
      child: chatListView,
    );
  }

  Widget _buildSettingButton(BuildContext context) {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    final icon = Icon(
      HugeIcons.strokeRoundedSettings01,
      color: colors.textPrimary,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        DesktopSettingProviderRoute().push(context);
      },
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }

  Widget _buildWorkspace() {
    var workspace = DesktopMessageList(
      controller: scrollController,
      onResend: resendMessage,
    );
    var desktopMessageInput = DesktopMessageInput(
      controller: controller,
      onRetentionChange: updateRetention,
      onImageSelected: updateImage,
      onImagePasted: chatViewModel.addPendingImage,
      onImageRemoved: chatViewModel.removePendingImage,
      onSubmitted: sendMessage,
      onTemperatureChange: updateTemperature,
      onReasoningEffortChange: updateReasoningEffort,
      onTerminated: terminateStreaming,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: workspace),
        desktopMessageInput,
      ],
    );
  }

  Future<void> _initState() async {
    await settingViewModel.initSignals();
    await chatViewModel.initSignals();
    await modelViewModel.loadEnabledModels();
    await sentinelViewModel.getSentinels();
  }

  void _openModelSelector() async {
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.warning('You should enable a provider first');
      return;
    }
    AthenaDialog.show(
      DesktopModelSelectDialog(
        onTap: (model) {
          AthenaDialog.dismiss();
          updateModel(model);
        },
      ),
      barrierDismissible: true,
    );
  }

  void _openSentinelSelector() async {
    if (sentinelViewModel.sentinels.value.isEmpty) {
      await sentinelViewModel.getSentinels();
    }
    if (sentinelViewModel.sentinels.value.isEmpty) {
      AthenaDialog.warning('No sentinels found');
      return;
    }
    AthenaDialog.show(
      DesktopSentinelSelectDialog(
        onTap: (sentinel) {
          AthenaDialog.dismiss();
          updateSentinel(sentinel);
        },
      ),
      barrierDismissible: true,
    );
  }
}
