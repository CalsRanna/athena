import 'dart:convert';
import 'dart:io';

import 'package:athena/entity/chat_entity.dart';
import 'package:athena/entity/message_entity.dart';
import 'package:athena/entity/model_entity.dart';
import 'package:athena/entity/sentinel_entity.dart';
import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/image_export.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/model_indicator.dart';
import 'package:athena/page/desktop/home/component/model_selector.dart';
import 'package:athena/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena/page/desktop/home/component/sentinel_selector.dart';
import 'package:athena/page/desktop/home/component/server_selector.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/view_model/server_view_model.dart';
import 'package:athena/view_model/setting_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
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
  final serverViewModel = GetIt.instance<ServerViewModel>();
  final settingViewModel = GetIt.instance<SettingViewModel>();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      var children = [_buildLeftBar(), Expanded(child: _buildWorkspace())];
      return AthenaScaffold(
        appBar: _buildAppBar(),
        body: Row(children: children),
      );
    });
  }

  Future<void> createChat() async {
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }

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

  void exportImage(ChatEntity chat) {
    AthenaDialog.show(
      DesktopImageExportDialog(chat: chat),
      barrierDismissible: true,
    );
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
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    var chat = chatViewModel.currentChat.value;
    if (chat == null) return;
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
    chatViewModel.isStreaming.value = false;
  }

  Future<void> updateContext(int context) async {
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
    var chat = chatViewModel.currentChat.value;
    if (chat == null) return;
    await chatViewModel.updateContext(context, chat: chat);
  }

  void updateImage(List<String> images) {
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
    chatViewModel.pendingImages.value = images;
  }

  Future<void> updateModel(ModelEntity newModel) async {
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
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
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
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
    if (chatViewModel.isStreaming.value) {
      AthenaDialog.info('Please wait for the current chat to finish.');
      return;
    }
    var chat = chatViewModel.currentChat.value;
    if (chat == null) return;
    await chatViewModel.updateTemperature(temperature, chat: chat);
  }

  Widget _buildAppBar() {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: ColorUtil.FFFFFFFF,
      size: 24,
    );
    var chatCreateButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
    return AthenaAppBar(
      action: _buildSettingButton(),
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
                _DesktopToolsButton(onTap: _openServerSelector),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onAutoRenamed: chatViewModel.renameChat,
      onBatchDestroyed: batchDestroyChats,
      onDestroyed: destroyChat,
      onExportedImage: exportImage,
      onManualRenamed: manualRenameChat,
      onPinned: chatViewModel.togglePin,
      onSelected: chatViewModel.selectChat,
    );
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      width: 240,
      child: chatListView,
    );
  }

  Widget _buildSettingButton() {
    const icon = Icon(
      HugeIcons.strokeRoundedSettings01,
      color: ColorUtil.FFFFFFFF,
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
    var images = chatViewModel.pendingImages.value;

    var workspace = DesktopMessageList(
      controller: scrollController,
      onResend: resendMessage,
    );
    var imageList = Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: _itemBuilder,
      ),
    );
    var desktopMessageInput = DesktopMessageInput(
      controller: controller,
      onContextChange: updateContext,
      onImageSelected: updateImage,
      onSubmitted: sendMessage,
      onTemperatureChange: updateTemperature,
      onTerminated: terminateStreaming,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: workspace),
        if (images.isNotEmpty) imageList,
        desktopMessageInput,
      ],
    );
  }

  Future<void> _initState() async {
    await settingViewModel.initSignals();
    await chatViewModel.initSignals();
    // var chat = await chatViewModel.getFirstChat();
    // if (chat != null) {
    //   await chatViewModel.selectChat(chat);
    // }
    await modelViewModel.loadEnabledModels();
    await sentinelViewModel.getSentinels();
    await serverViewModel.loadServers();
  }

  Widget _itemBuilder(context, index) {
    var images = chatViewModel.pendingImages.value;
    var image = Image.file(
      File(images[index]),
      fit: BoxFit.cover,
      height: double.infinity,
      width: double.infinity,
    );
    var icon = Icon(
      HugeIcons.strokeRoundedCancel01,
      color: ColorUtil.FFFFFFFF,
      size: 12,
    );
    var decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: ColorUtil.FF282F32,
    );
    var container = Container(
      decoration: decoration,
      padding: EdgeInsets.all(2),
      child: icon,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => chatViewModel.removePendingImage(index),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
    var children = [
      image,
      Positioned(right: 2, top: 2, child: gestureDetector),
    ];
    return AspectRatio(aspectRatio: 1, child: Stack(children: children));
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

  void _openServerSelector() {
    AthenaDialog.show(
      const DesktopServerSelectDialog(),
      barrierDismissible: true,
    );
  }
}

class _DesktopToolsButton extends StatefulWidget {
  final void Function()? onTap;

  const _DesktopToolsButton({this.onTap});

  @override
  State<_DesktopToolsButton> createState() => _DesktopToolsButtonState();
}

class _DesktopToolsButtonState extends State<_DesktopToolsButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final serverViewModel = GetIt.instance<ServerViewModel>();
    return Watch((context) {
      var enabledCount = serverViewModel.servers.value
          .where((s) => s.enabled)
          .length;
      var foregroundColor = ColorUtil.FFFFFFFF.withValues(
        alpha: enabledCount > 0 ? 0.86 : 0.72,
      );
      var gradient = LinearGradient(
        begin: Alignment.topLeft,
        colors: [
          ColorUtil.FFEAEAEA.withValues(alpha: hover ? 0.18 : 0.1),
          ColorUtil.FFFFFFFF.withValues(alpha: hover ? 0.03 : 0),
        ],
        end: Alignment.bottomRight,
      );
      var innerColor = enabledCount > 0
          ? ColorUtil.FF161616.withValues(alpha: hover ? 0.98 : 0.94)
          : ColorUtil.FF161616.withValues(alpha: hover ? 0.86 : 0.78);
      var icon = Icon(
        HugeIcons.strokeRoundedTools,
        color: foregroundColor,
        size: 15,
      );
      var inner = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: innerColor,
          borderRadius: BorderRadius.circular(16),
        ),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (enabledCount > 0) ...[
              const SizedBox(width: 5),
              Text(
                '$enabledCount',
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      );
      var button = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(17),
        ),
        padding: const EdgeInsets.all(1),
        child: inner,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: _handleEnter,
          onExit: _handleExit,
          child: button,
        ),
      );
    });
  }

  void _handleEnter(PointerEnterEvent event) {
    setState(() {
      hover = true;
    });
  }

  void _handleExit(PointerExitEvent event) {
    setState(() {
      hover = false;
    });
  }
}
