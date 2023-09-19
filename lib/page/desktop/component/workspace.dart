import 'dart:io';

import 'package:athena/page/desktop/component/input.dart';
import 'package:athena/page/desktop/component/message_list.dart';
import 'package:athena/page/desktop/component/model_segment_controller.dart';
import 'package:athena/page/desktop/component/toolbar.dart';
import 'package:flutter/material.dart';

class WorkSpace extends StatelessWidget {
  const WorkSpace({super.key});

  @override
  Widget build(BuildContext context) {
    var padding = const EdgeInsets.symmetric(vertical: 16);
    if (Platform.isWindows) {
      padding = const EdgeInsets.only(bottom: 8);
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (Platform.isWindows) const Toolbar(),
          const ModelSegmentController(),
          const Expanded(child: MessageList()),
          const Input(),
        ],
      ),
    );
  }
}
