import 'package:athena/page/desktop/workspace/component/input.dart';
import 'package:athena/page/desktop/workspace/component/message.dart';
import 'package:flutter/material.dart';

class WorkSpace extends StatelessWidget {
  const WorkSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 50),
          Expanded(child: MessageList()),
          Input(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}
