import 'dart:convert';
import 'dart:io';

import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/image_export.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/model_indicator.dart';
import 'package:athena/page/desktop/home/component/sentinel_indicator.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/dialog.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class DesktopHomePage extends ConsumerStatefulWidget {
  const DesktopHomePage({super.key});

  @override
  ConsumerState<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends ConsumerState<DesktopHomePage> {
  var chat = Chat();
  var model = Model();
  var sentinel = Sentinel();
  var images = <String>[];

  final controller = TextEditingController();
  final scrollController = ScrollController();
  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var children = [_buildLeftBar(), Expanded(child: _buildWorkspace())];
    return AthenaScaffold(
      appBar: _buildAppBar(),
      body: Row(children: children),
    );
  }

  Future<void> changeChat(Chat chat) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    var model = await viewModel.getModel(chat.modelId);
    var sentinel = await viewModel.getSentinel(chat.sentinelId);
    setState(() {
      this.chat = chat;
      this.model = model;
      this.sentinel = sentinel;
      images = [];
    });
  }

  Future<void> createChat() async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    if (!await viewModel.hasModel()) {
      AthenaDialog.message('You should enable a provider first');
      return;
    }
    _initChat();
    _initModel();
    _initSentinel();
    var chat = await viewModel.createChat();
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> destroyChat(Chat chat) async {
    var result = await AthenaDialog.confirm('Do you want to delete this chat?');
    if (result == true) {
      var duration = Duration(milliseconds: 300);
      if (scrollController.hasClients) {
        scrollController.animateTo(0, curve: Curves.linear, duration: duration);
      }
      await viewModel.destroyChat(chat);
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

  void exportImage(Chat chat) {
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

  Future<void> resendMessage(Message message) async {
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    await viewModel.resendMessage(message, chat: chat);
  }

  Future<void> sendMessage() async {
    var text = controller.text.trim();
    if (text.isEmpty) return;
    if (model.id <= 0) {
      AthenaDialog.message('You should select a model first');
      return;
    }
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
    var message = Message()
      ..content = text
      ..imageUrls = imageUrls.join(',');
    setState(() {
      images = [];
    });
    await viewModel.sendMessage(message, chat: chat);
    if (chat.title.isEmpty || chat.title == 'New Chat') {
      var renamedChat = await viewModel.renameChat(chat);
      setState(() {
        chat = renamedChat;
      });
    }
  }

  Future<void> terminateStreaming() async {
    viewModel.terminateStreaming(chat);
  }

  Future<void> updateContext(int context) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    var chat = await viewModel.updateContext(context, chat: this.chat);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> updateEnableSearch(bool enabled) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    var chat = await viewModel.updateEnableSearch(enabled, chat: this.chat);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> updateImage(List<String> images) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      this.images = images;
    });
  }

  Future<void> updateModel(Model model) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      this.model = model;
    });
    var chat = await viewModel.updateModel(model, chat: this.chat);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> updateSentinel(Sentinel sentinel) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    setState(() {
      this.sentinel = sentinel;
    });
    var chat = await viewModel.updateSentinel(sentinel, chat: this.chat);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> updateTemperature(double temperature) async {
    if (viewModel.streaming) {
      AthenaDialog.message('Please wait for the current chat to finish.');
      return;
    }
    var chat = await viewModel.updateTemperature(temperature, chat: this.chat);
    setState(() {
      this.chat = chat;
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
          DesktopSentinelIndicator(chat: chat),
          DesktopModelIndicator(chat: chat),
        ],
      ),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onDestroyed: destroyChat,
      onExportedImage: exportImage,
      onRenamed: viewModel.renameChat,
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
      onTap: () => viewModel.navigateSettingPage(context),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: icon),
    );
  }

  Widget _buildWorkspace() {
    var workspace = DesktopMessageList(
      chat: chat,
      controller: scrollController,
      onResend: resendMessage,
      sentinel: sentinel,
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
      chat: chat,
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
    var chat = await viewModel.getFirstChat();
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> _initModel() async {
    var model = await viewModel.getFirstEnabledModel();
    setState(() {
      this.model = model;
    });
  }

  Future<void> _initSentinel() async {
    var sentinel = await viewModel.getFirstSentinel();
    setState(() {
      this.sentinel = sentinel;
    });
  }

  Future<void> _initState() async {
    await viewModel.initChats();
    _initChat();
    _initModel();
    _initSentinel();
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
