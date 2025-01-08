import 'package:athena/page/desktop/home/component/indicator.dart';
import 'package:athena/page/desktop/home/component/left_bar.dart';
import 'package:athena/page/desktop/home/component/workspace.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  Chat? chat;
  Sentinel? sentinel;
  @override
  Widget build(BuildContext context) {
    var children = [
      DesktopLeftBar(
        onDestroyed: destroyChat,
        onSelected: selectChat,
        onSentinelChanged: changeSentinel,
        selectedChat: chat,
      ),
      Expanded(child: WorkSpace(chat: chat, onSubmitted: submit)),
    ];
    return AScaffold(
      appBar: AAppBar(
        onCreated: createChat,
        title: DesktopChatIndicator(chat: chat),
      ),
      body: Row(children: children),
    );
  }

  void createChat() {
    setState(() {
      chat = null;
    });
  }

  void destroyChat() {
    setState(() {
      chat = null;
    });
  }

  void changeSentinel(Sentinel sentinel) {
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat?.id ?? 0);
    var notifier = container.read(provider.notifier);
    notifier.updateSentinel(sentinel);
    if (chat == null) {
      setState(() {
        chat = Chat()..sentinelId = sentinel.id;
      });
    } else {
      setState(() {
        chat = chat!.copyWith(sentinelId: sentinel.id);
      });
    }
  }

  void selectChat(Chat chat) {
    setState(() {
      this.chat = chat;
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
      notifier.send(text);
    });
  }
}
