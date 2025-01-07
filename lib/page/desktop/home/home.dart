import 'package:athena/page/desktop/home/component/left_bar.dart';
import 'package:athena/page/desktop/home/component/indicator.dart';
import 'package:athena/page/desktop/home/component/workspace.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  Chat? chat;
  @override
  Widget build(BuildContext context) {
    return AScaffold(
      appBar: AAppBar(onCreated: createChat, title: DesktopChatIndicator()),
      body: Row(
        children: [
          DesktopLeftBar(onSelected: selectChat, selectedChat: chat),
          Expanded(child: WorkSpace(chat: chat)),
        ],
      ),
    );
  }

  void createChat() {
    setState(() {
      chat = null;
    });
  }

  void selectChat(Chat chat) {
    setState(() {
      this.chat = chat;
    });
  }
}
