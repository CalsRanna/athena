import 'package:athena/page/desktop/home/component/input.dart';
import 'package:athena/page/desktop/home/component/message.dart';
import 'package:flutter/material.dart';

class WorkSpace extends StatelessWidget {
  const WorkSpace({super.key});

  @override
  Widget build(BuildContext context) {
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: MessageList()), Input()],
    );
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    return Container(
      decoration: BoxDecoration(border: Border(left: borderSide)),
      child: column,
    );
  }
}
