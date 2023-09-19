import 'package:athena/creator/chat.dart';
import 'package:athena/main.dart';
import 'package:athena/page/desktop/component/chat_list.dart';
import 'package:athena/page/desktop/component/workspace.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

class Desktop extends StatefulWidget {
  const Desktop({super.key});

  @override
  State<Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<Desktop> {
  bool showFloatingActionButton = false;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void didChangeDependencies() {
    getChats();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void init() async {
    scrollController = ScrollController();
    scrollController.addListener(() {
      setState(() {
        showFloatingActionButton = scrollController.position.extentBefore != 0;
      });
    });
  }

  void getChats() async {
    final ref = context.ref;
    var chats = await isar.chats.where().findAll();
    chats = chats.map((chat) {
      return chat.withGrowableMessages();
    }).toList();
    ref.set(chatsCreator, [...chats]);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Row(children: [ChatList(), Expanded(child: WorkSpace())]),
        ],
      ),
    );
  }
}
