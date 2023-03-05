import 'package:athena/page/chat_assistant.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(CreatorGraph(child: const AthenaApp()));
}

class AthenaApp extends StatelessWidget {
  const AthenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ChatAssistant(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}
