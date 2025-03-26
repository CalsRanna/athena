import 'package:athena/page/desktop/home/component/chat_configuration_sheet.dart';
import 'package:athena/page/desktop/home/component/model_indicator.dart';
import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
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
  var showRightSheet = false;

  final controller = TextEditingController();
  final scrollController = ScrollController();
  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var children = [
      _buildLeftBar(),
      Expanded(child: _buildWorkspace()),
      _buildRightSheet(),
    ];
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
      showRightSheet = false;
    });
  }

  Future<void> destroyChat(Chat chat) async {
    var duration = Duration(milliseconds: 300);
    if (scrollController.hasClients) {
      scrollController.animateTo(0, curve: Curves.linear, duration: duration);
    }
    await viewModel.destroyChat(chat);
    _initChat();
    _initModel();
    _initSentinel();
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
    await viewModel.sendMessage(text, chat: chat);
    if (chat.title.isEmpty || chat.title == 'New Chat') {
      var renamedChat = await viewModel.renameChat(chat);
      setState(() {
        chat = renamedChat;
      });
    }
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

  void updateShowRightSheet() {
    setState(() {
      showRightSheet = !showRightSheet;
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
          DesktopModelIndicator(chat: chat)
        ],
      ),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onDestroyed: destroyChat,
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

  Widget _buildRightSheet() {
    if (!showRightSheet) return SizedBox();
    var borderSide = BorderSide(
      color: ColorUtil.FFFFFFFF.withValues(alpha: 0.2),
    );
    var boxDecoration = BoxDecoration(border: Border(left: borderSide));
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      width: 240,
      child: DesktopChatConfigurationSheet(chat: chat),
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
    var desktopMessageInput = DesktopMessageInput(
      chat: chat,
      controller: controller,
      onChatConfigurationButtonTapped: updateShowRightSheet,
      onModelChanged: updateModel,
      onSentinelChanged: updateSentinel,
      onSubmitted: sendMessage,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: workspace), desktopMessageInput],
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
}
