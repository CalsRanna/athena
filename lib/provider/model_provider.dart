import 'package:athena/creator/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';

class ModelProvider {
  BuildContext context;
  List<String> models = ['gpt-3.5-turbo-16k', 'gpt-4'];

  ModelProvider(this.context);

  static ModelProvider of(BuildContext context) {
    return ModelProvider(context);
  }

  void animate() {
    final ref = context.ref;
    final chats = ref.read(chatsCreator);
    final current = ref.read(currentChatCreator);
    if (current == null) return;
    final chat = chats[current];
    final model = chat.model;
    final index = models.indexOf(model);
    final controller = ref.read(animationControllerCreator);
    controller?.animateTo(index.toDouble());
  }
}
