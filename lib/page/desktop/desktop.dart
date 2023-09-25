import 'package:athena/page/desktop/component/chat_list.dart';
import 'package:athena/page/desktop/component/workspace.dart';
import 'package:flutter/material.dart';

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
