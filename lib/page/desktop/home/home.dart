import 'package:athena/page/desktop/home/component/chat_indicator.dart';
import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
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
  Chat? chat;
  Model? model;
  Sentinel? sentinel;
  final controller = TextEditingController();
  late final viewModel = ChatViewModel(ref);

  @override
  Widget build(BuildContext context) {
    var children = [_buildLeftBar(), Expanded(child: _buildRightWorkspace())];
    return AScaffold(appBar: _buildAppBar(), body: Row(children: children));
  }

  Future<void> changeChat(Chat chat) async {
    if (viewModel.streaming) {
      return ADialog.message('Please wait for the current chat to finish.');
    }
    var model = await viewModel.getModel(chat.modelId);
    var sentinel = await viewModel.getSentinel(chat.sentinelId);
    setState(() {
      this.chat = chat;
      this.model = model;
      this.sentinel = sentinel;
    });
  }

  Future<void> changeModel(Model model) async {
    if (viewModel.streaming) {
      return ADialog.message('Please wait for the current chat to finish.');
    }
    setState(() {
      this.model = model;
    });
    if (this.chat == null) return;
    var chat = await viewModel.selectModel(model, chat: this.chat!);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> changeSentinel(Sentinel sentinel) async {
    if (viewModel.streaming) {
      return ADialog.message('Please wait for the current chat to finish.');
    }
    setState(() {
      this.sentinel = sentinel;
    });
    if (this.chat == null) return;
    var chat = await viewModel.selectSentinel(sentinel, chat: this.chat!);
    setState(() {
      this.chat = chat;
    });
  }

  Future<void> createChat() async {
    if (viewModel.streaming) {
      return ADialog.message('Please wait for the current chat to finish.');
    }
    setState(() {
      chat = null;
    });
    _initModel();
    _initSentinel();
  }

  Future<void> destroyChat() async {
    await viewModel.destroyChat(chat!);
    _initChat();
    _initModel();
    _initSentinel();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> resendMessage(Message message) async {
    if (model == null || sentinel == null) return;
    await viewModel.resendMessage(
      message,
      chat: chat!,
      model: model!,
      sentinel: sentinel!,
    );
  }

  Future<void> sendMessage() async {
    if (model == null || sentinel == null) return;
    if (chat == null) {
      var chat = await viewModel.createChat(model: model!, sentinel: sentinel!);
      setState(() {
        this.chat = chat;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var text = controller.text.trim();
      if (text.isEmpty) return;
      viewModel.sendMessage(
        text,
        chat: chat!,
        model: model!,
        sentinel: sentinel!,
      );
      controller.clear();
    });
  }

  Widget _buildAppBar() {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: Colors.white,
      size: 24,
    );
    var chatCreateButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: icon,
    );
    return AAppBar(
      action: _buildSettingButton(),
      leading: Align(alignment: Alignment.centerRight, child: chatCreateButton),
      title: DesktopChatIndicator(model: model, sentinel: sentinel),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onDestroyed: destroyChat,
      onSelected: changeChat,
      selectedChat: chat,
    );
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      width: 200,
      child: chatListView,
    );
  }

  Widget _buildRightWorkspace() {
    Widget workspace = DesktopSentinelPlaceholder(sentinel: sentinel);
    if (chat != null) {
      workspace = DesktopMessageList(chat: chat!, onResend: resendMessage);
    }
    var desktopMessageInput = DesktopMessageInput(
      controller: controller,
      onModelChanged: changeModel,
      onSentinelChanged: changeSentinel,
      onSubmitted: sendMessage,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: workspace), desktopMessageInput],
    );
  }

  Widget _buildSettingButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => viewModel.navigateSettingPage(context),
      child: const Icon(HugeIcons.strokeRoundedSettings01, color: Colors.white),
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
    await _initChat();
    if (chat != null) {
      var model = await viewModel.getModel(chat!.modelId);
      var sentinel = await viewModel.getSentinel(chat!.sentinelId);
      setState(() {
        this.model = model;
        this.sentinel = sentinel;
      });
    } else {
      _initModel();
      _initSentinel();
    }
  }
}
