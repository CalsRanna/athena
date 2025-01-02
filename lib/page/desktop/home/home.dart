import 'package:athena/page/desktop/home/component/chat.dart';
import 'package:athena/page/desktop/home/component/indicator.dart';
import 'package:athena/page/desktop/home/component/workspace.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DesktopHomePage extends StatelessWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AScaffold(
      appBar: AAppBar(title: DesktopChatIndicator()),
      body: Row(children: [ChatList(), Expanded(child: WorkSpace())]),
    );
  }
}
