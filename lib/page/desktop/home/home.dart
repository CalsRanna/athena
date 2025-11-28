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
import 'package:athena/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat_view_model.dart';
import 'package:athena/view_model/model_view_model.dart';
import 'package:athena/view_model/sentinel_view_model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  // Flutter 资源管理
  final controller = TextEditingController();
  final scrollController = ScrollController();
  late final viewModel = GetIt.instance<ChatViewModel>();

  // 临时本地缓存(用于避免 Watch 包装整个 widget tree)
  // TODO: 后续应该完全移除,所有引用改为 viewModel.currentXxx.value 并使用 Watch
  ChatEntity? chat;
  ModelEntity? model;
  SentinelEntity? sentinel;
  var images = <String>[];

  @override
  Widget build(BuildContext context) {
    var children = [_buildLeftBar(), Expanded(child: _buildWorkspace())];
    return AthenaScaffold(
      appBar: _buildAppBar(),
      body: Row(children: children),
    );
  }

  Future<void> changeChat(ChatEntity newChat) async {
    await viewModel.selectChat(newChat);
    // 同步本地缓存
    setState(() {
      chat = viewModel.currentChat.value;
      model = viewModel.currentModel.value;
      sentinel = viewModel.currentSentinel.value;
      images = [];
    });
  }

  Future<void> createChat() async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }

    var modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isEmpty) {
      AthenaDialog.message('You should enable a provider first');
      return;
    }

    await viewModel.createChat();
    // 同步本地缓存
    setState(() {
      chat = viewModel.currentChat.value;
      model = viewModel.currentModel.value;
      sentinel = viewModel.currentSentinel.value;
      images = [];
    });
  }

  Future<void> autoRenameChat(ChatEntity chat) async {
    await viewModel.renameChat(chat);
  }

  Future<void> destroyChat(ChatEntity chat) async {
    var result = await AthenaDialog.confirm('Do you want to delete this chat?');
    if (result == true) {
      var duration = Duration(milliseconds: 300);
      if (scrollController.hasClients) {
        scrollController.animateTo(0, curve: Curves.linear, duration: duration);
      }
      await viewModel.deleteChat(chat);
      _initChat();
      _initModel();
      _initSentinel();
    }
  }

  Future<void> destroyImage(int index) async {
    setState(() {
      images.removeAt(index);
    });
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
      await viewModel.renameChatManually(chat, title);
    }
  }

  Future<void> resendMessage(MessageEntity message) async {
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    if (chat == null) return;
    await viewModel.deleteMessage(message);
    // After deleting, reload messages for UI update
    await viewModel.loadMessages(chat!.id!);
  }

  Future<void> sendMessage() async {
    var text = controller.text.trim();
    if (text.isEmpty) return;
    if (model == null || model!.id! <= 0) {
      AthenaDialog.message('You should select a model first');
      return;
    }
    if (chat == null) return;

    controller.clear();
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    var imageUrls = <String>[];
    for (var image in images) {
      var bytes = await File(image).readAsBytes();
      imageUrls.add(base64Encode(bytes));
    }

    var message = MessageEntity(
      id: 0,
      chatId: chat!.id ?? 0,
      role: 'user',
      content: text,
      imageUrls: imageUrls.join(','),
    );
    setState(() {
      images = [];
    });

    await viewModel.sendMessage(message, chat: chat!);

    // Auto-rename chat after first message
    if (chat!.title.isEmpty || chat!.title == 'New Chat') {
      var renamedChat = await viewModel.renameChat(chat!);
      if (renamedChat != null) {
        setState(() {
          chat = renamedChat;
        });
      }
    }
  }

  Future<void> terminateStreaming() async {
    if (chat == null) return;
    // Set streaming to false to stop the stream
    viewModel.isStreaming.value = false;
  }

  Future<void> updateContext(int context) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    if (chat == null) return;
    var updatedChat = await viewModel.updateContext(context, chat: chat!);
    setState(() {
      chat = updatedChat;
    });
  }

  Future<void> updateEnableSearch(bool enabled) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    if (chat == null) return;
    var updatedChat = await viewModel.updateEnableSearch(enabled, chat: chat!);
    setState(() {
      chat = updatedChat;
    });
  }

  Future<void> updateImage(List<String> images) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      this.images = images;
    });
  }

  Future<void> updateModel(ModelEntity newModel) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      model = newModel;
    });
    if (chat == null) return;
    var updatedChat = await viewModel.updateModel(newModel, chat: chat!);
    setState(() {
      chat = updatedChat;
    });
  }

  Future<void> updateSentinel(SentinelEntity newSentinel) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      sentinel = newSentinel;
    });
    if (chat == null) return;
    var updatedChat = await viewModel.updateSentinel(newSentinel, chat: chat!);
    setState(() {
      chat = updatedChat;
    });
  }

  Future<void> updateTemperature(double temperature) async {
    if (viewModel.isStreaming.value) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    if (chat == null) return;
    var updatedChat = await viewModel.updateTemperature(
      temperature,
      chat: chat!,
    );
    setState(() {
      chat = updatedChat;
    });
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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        spacing: 8,
        children: [
          if (chat != null) DesktopSentinelIndicator(chat: chat!),
          if (chat != null) DesktopModelIndicator(chat: chat!),
        ],
      ),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onAutoRenamed: autoRenameChat,
      onDestroyed: destroyChat,
      onExportedImage: exportImage,
      onManualRenamed: manualRenameChat,
      onPinned: (chat) {
        viewModel.togglePin(chat);
      },
      onSelected: changeChat,
      selectedChat: chat,
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
        DesktopSettingRoute().push(context);
      },
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }

  Widget _buildWorkspace() {
    if (chat == null) {
      return Center(child: Text('No chat selected'));
    }
    if (sentinel == null) {
      return Center(child: Text('No sentinel selected'));
    }

    var workspace = DesktopMessageList(
      chat: chat!,
      controller: scrollController,
      onResend: resendMessage,
      sentinel: sentinel!,
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
      chat: chat!,
      controller: controller,
      onContextChange: updateContext,
      onImageSelected: updateImage,
      onModelChanged: updateModel,
      onSentinelChanged: updateSentinel,
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

  Future<void> _initChat() async {
    var chatViewModel = GetIt.instance<ChatViewModel>();
    var chat = await chatViewModel.getFirstChat();
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> _initModel() async {
    var modelViewModel = GetIt.instance<ModelViewModel>();
    await modelViewModel.loadEnabledModels();
    if (modelViewModel.enabledModels.value.isNotEmpty) {
      setState(() {
        model = modelViewModel.enabledModels.value.first;
      });
    }
  }

  Future<void> _initSentinel() async {
    var sentinelViewModel = GetIt.instance<SentinelViewModel>();
    await sentinelViewModel.getSentinels();
    if (sentinelViewModel.sentinels.value.isNotEmpty) {
      setState(() {
        sentinel = sentinelViewModel.sentinels.value.first;
      });
    }
  }

  Future<void> _initState() async {
    var chatViewModel = GetIt.instance<ChatViewModel>();
    await chatViewModel.initChats();
    await _initChat();
    await _initModel();
    await _initSentinel();
  }

  Widget _itemBuilder(context, index) {
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
      onTap: () => destroyImage(index),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: container),
    );
    var children = [
      image,
      Positioned(right: 2, top: 2, child: gestureDetector),
    ];
    return AspectRatio(aspectRatio: 1, child: Stack(children: children));
  }
}
