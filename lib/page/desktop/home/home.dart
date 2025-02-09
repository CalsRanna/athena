import 'package:athena/page/desktop/home/component/chat_indicator.dart';
import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/chat_search.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/page/desktop/home/component/sentinel_tile.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
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
    if (chat == null) return;
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat!.id);
    var notifier = container.read(provider.notifier);
    notifier.updateModel(model.value);
  }

  void changeSentinel(Sentinel sentinel) {
    setState(() {
      this.sentinel = sentinel;
    });
    if (chat == null) return;
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat!.id);
    var notifier = container.read(provider.notifier);
    notifier.updateSentinel(sentinel);
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
    if (chat == null) {
      var container = ProviderScope.containerOf(context);
      var provider = chatNotifierProvider(chat?.id ?? 0);
      var notifier = container.read(provider.notifier);
      var chatId = await notifier.create(model: model, sentinel: sentinel);
      setState(() {
        chat = Chat()..id = chatId;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var container = ProviderScope.containerOf(context);
      var provider = chatNotifierProvider(chat!.id);
      var notifier = container.read(provider.notifier);
      notifier.send(text);
    });
  }

  Widget _buildAppBar() {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: Colors.white,
      size: 24,
    );
    var gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: icon,
    );
    var leadingChildren = [
      // Calculated by the width of MacWindowButton
      const SizedBox(width: 54),
      const SizedBox(width: 16),
      gestureDetector,
      const SizedBox(width: 16),
    ];
    return AAppBar(
      leading: Row(children: leadingChildren),
      title: DesktopChatIndicator(model: model, sentinel: sentinel),
    );
    // return Row(children: rowChildren);
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
