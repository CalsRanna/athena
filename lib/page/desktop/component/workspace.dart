import 'package:athena/page/desktop/component/input.dart';
import 'package:athena/page/desktop/component/message_list.dart';
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
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined),
              SizedBox(width: 8),
              Expanded(child: Input()),
            ],
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}
