import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/chat_indicator.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/page/desktop/home/component/chat_search.dart';
import 'package:athena/page/desktop/home/component/sentinel_tile.dart';
import 'package:athena/page/desktop/home/component/setting_tile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:athena/widget/window_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar/isar.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  Chat? chat;
  Model? model;
  Sentinel? sentinel;
  @override
  Widget build(BuildContext context) {
    var children = [_buildLeftBar(), Expanded(child: _buildRightWorkspace())];
    return AScaffold(appBar: _buildAppBar(), body: Row(children: children));
  }

  Widget _buildAppBar() {
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: Icon(HugeIcons.strokeRoundedPencilEdit02, color: Colors.white),
    );
    var container = Container(
      alignment: Alignment.centerRight,
      height: 50,
      padding: EdgeInsets.only(right: 16),
      width: 200,
      child: gestureDetector,
    );
    var stackChildren = [
      container,
      const Positioned(left: 16, top: 18, child: MacWindowButton())
    ];
    var rowChildren = [
      Stack(children: stackChildren),
      Expanded(child: DesktopChatIndicator(model: model, sentinel: sentinel)),
    ];
    return Row(children: rowChildren);
  }

  Future<void> changeChat(Chat chat) async {
    var model = await isar.models.filter().valueEqualTo(chat.model).findFirst();
    var sentinel =
        await isar.sentinels.filter().idEqualTo(chat.sentinelId).findFirst();
    setState(() {
      this.chat = chat;
      this.model = model;
      this.sentinel = sentinel;
    });
  }

  void changeModel(Model model) {
    setState(() {
      this.model = model;
    });
  }

  void changeSentinel(Sentinel sentinel) {
    setState(() {
      this.sentinel = sentinel;
    });
  }

  void createChat() {
    setState(() {
      chat = null;
      model = null;
      sentinel = null;
    });
  }

  void destroyChat() {
    setState(() {
      chat = null;
      model = null;
      sentinel = null;
    });
  }

  Future<void> submit(String text) async {
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat?.id ?? 0);
    var notifier = container.read(provider.notifier);
    if (chat == null) {
      var chatId = await notifier.create();
      setState(() {
        chat = Chat()..id = chatId;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var provider = chatNotifierProvider(chat!.id);
      var notifier = container.read(provider.notifier);
      notifier.send(text, model: model, sentinel: sentinel);
    });
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onDestroyed: destroyChat,
      onSelected: changeChat,
      selectedChat: chat,
    );
    List<Widget> children = [
      DesktopChatSearch(),
      Expanded(child: chatListView),
      DesktopSentinelTile(onChanged: changeSentinel),
      DesktopSettingTile()
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      width: 200,
      child: column,
    );
  }

  Widget _buildRightWorkspace() {
    var stackChildren = [
      if (chat == null) DesktopSentinelPlaceholder(sentinel: sentinel),
      DesktopMessageList(chat: chat),
    ];
    var children = [
      Expanded(child: Stack(children: stackChildren)),
      DesktopMessageInput(onModelChanged: changeModel, onSubmitted: submit)
    ];
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    return Container(
      decoration: BoxDecoration(border: Border(left: borderSide)),
      child: column,
    );
  }
}
