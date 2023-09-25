import 'dart:async';

import 'package:athena/api/chat.dart';
import 'package:athena/creator/chat.dart';
import 'package:athena/creator/input.dart';
import 'package:athena/main.dart';
import 'package:athena/provider/model_provider.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class ChatProvider {
  BuildContext context;
  final models = ['gpt-3.5-turbo-16k', 'gpt-4'];

  ChatProvider(this.context);

  static ChatProvider of(BuildContext context) {
    return ChatProvider(context);
  }

  void create() async {
    final ref = context.ref;
    final chat = Chat();
    chat.title = '新建对话';
    chat.model = 'gpt-3.5-turbo-16k';
    final modelProvider = ModelProvider.of(context);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    final chats = ref.read(chatsCreator);
    chats.add(chat);
    ref.set(chatsCreator, [...chats]);
    ref.set(currentChatCreator, chats.length - 1);
    final node = ref.read(focusNodeCreator);
    node.requestFocus();
    final controller = ref.read(textEditingControllerCreator);
    controller.clear();
    modelProvider.animate();
  }

  void getChats() async {
    final ref = context.ref;
    final modelProvider = ModelProvider.of(context);
    var chats = await isar.chats.where().findAll();
    chats = chats.map((chat) {
      return chat.withGrowableMessages();
    }).toList();
    ref.set(chatsCreator, [...chats]);
    if (chats.isNotEmpty) {
      final index = chats.length - 1;
      ref.set(currentChatCreator, index);
    }
    modelProvider.animate();
  }

  void selectChat(int index) {
    context.ref.set(currentChatCreator, index);
    ModelProvider.of(context).animate();
  }

  void deleteChat(int index) async {
    final ref = context.ref;
    var chats = ref.read(chatsCreator);
    final chat = chats[index];
    final modelProvider = ModelProvider.of(context);
    try {
      await isar.writeTxn(() async {
        await isar.chats.delete(chat.id);
      });
      chats = await isar.chats.where().findAll();
      chats = chats.map((chat) {
        return chat.withGrowableMessages();
      }).toList();
      ref.set(chatsCreator, [...chats]);
      if (chats.isNotEmpty) {
        ref.set(currentChatCreator, chats.length - 1);
      } else {
        ref.set(currentChatCreator, null);
      }
      modelProvider.animate();
    } catch (error) {
      Logger().e(error);
    }
  }

  void updateChat(String model) {
    context.ref.set(modelCreator, model);
    final current = context.ref.read(currentChatCreator);
    if (current == null) return;
    final chats = context.ref.read(chatsCreator);
    chats[current].model = model;
    context.ref.set(chatsCreator, [...chats]);
    isar.writeTxn(() async {
      await isar.chats.put(chats[current]);
    });
  }

  void submit() async {
    final node = context.ref.read(focusNodeCreator);
    node.unfocus();
    final controller = context.ref.read(textEditingControllerCreator);
    final text = controller.text;
    if (text.trim().isNotEmpty) {
      context.ref.set(streamingCreator, true);
      final chats = context.ref.read(chatsCreator);
      final current = context.ref.watch(currentChatCreator);
      if (current == null) return;
      final chat = chats[current];
      final message = Message()
        ..role = 'user'
        ..content = text;
      chat.messages.add(message);
      chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
      context.ref.set(chatsCreator, [...chats]);
      _storeChat(chat);
      controller.clear();
      _fetchResponse(chat);
      final conditionA = chat.title == null;
      final conditionB = chat.title != null && chat.title!.isEmpty;
      final conditionC = chat.title != null && chat.title! == '新建对话';
      if (conditionA || conditionB || conditionC) {
        getTitle(chat, chat.messages.first.content ?? text);
      }
    }
  }

  Future<void> _storeChat(Chat chat) async {
    final ref = context.ref;
    try {
      if (!chat.model.startsWith('gpt')) {
        chat.model = 'gpt-3.5-turbo-16k';
      }
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
      });
      var chats = await isar.chats.where().findAll();
      chats = chats.map((chat) {
        return chat.withGrowableMessages();
      }).toList();
      ref.set(chatsCreator, [...chats]);
    } catch (error) {
      Logger().e(error);
    }
  }

  Future<void> _fetchResponse(Chat chat) async {
    final ref = context.ref;
    scrollToBottom();
    chat.messages.add(Message()..role = 'assistant');
    try {
      final messages = chat.messages.where((message) {
        return message.role != 'error' && message.content != null;
      }).toList();
      final stream = await ChatApi().getCompletion(
        messages: messages,
        model: chat.model,
      );
      stream.listen(
        (token) {
          chat.messages.last.role = 'assistant';
          chat.messages.last.content =
              '${chat.messages.last.content ?? ''}$token';
          chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
          _storeChat(chat);
        },
        onDone: () {
          chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
          context.ref.set(streamingCreator, false);
          _storeChat(chat);
        },
      );
    } catch (error) {
      Logger().e(error);
      final message = Message()
        ..role = 'error'
        ..content = error.toString();
      chat.messages.last = message;
      chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
      ref.set(streamingCreator, false);
      _storeChat(chat);
    }
  }

  Future<void> getTitle(Chat chat, String value) async {
    try {
      final stream = await ChatApi().getTitle(value: value);
      stream.listen(
        (token) {
          chat.title = '${chat.title ?? ''}$token'.trim().replaceAll('。', '');
          chat.title = chat.title?.replaceAll('新建对话', '');
          _storeChat(chat);
        },
      );
    } catch (error) {
      Logger().e(error);
    }
  }

  void scrollToBottom() {
    final controller = context.ref.read(scrollControllerCreator);
    Timer(const Duration(milliseconds: 16), () {
      try {
        controller.animateTo(
          controller.position.minScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutQuart,
        );
      } catch (error) {
        Logger().e(error);
      }
    });
  }

  Future<void> delete(int index) async {
    final chats = context.ref.read(chatsCreator);
    final current = context.ref.watch(currentChatCreator);
    if (current == null) return;
    final chat = chats[current];
    final realIndex = chat.messages.length - 1 - index;
    chat.messages.removeRange(realIndex, chat.messages.length);
    if (chat.messages.isEmpty) {
      chat.title = null;
    }
    chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
    context.ref.set(chatsCreator, [...chats]);
    _storeChat(chat);
  }

  void edit(int index) {
    final chats = context.ref.read(chatsCreator);
    final current = context.ref.watch(currentChatCreator);
    if (current == null) return;
    final chat = chats[current];
    final realIndex = chat.messages.length - 1 - index;
    final message = chat.messages.elementAt(realIndex);
    final controller = context.ref.read(textEditingControllerCreator);
    final node = context.ref.read(focusNodeCreator);
    controller.text = message.content ?? '';
    node.requestFocus();
  }

  Future<void> retry(int index) async {
    context.ref.set(streamingCreator, true);
    delete(index);
    final chats = context.ref.read(chatsCreator);
    final current = context.ref.watch(currentChatCreator);
    if (current == null) return;
    final chat = chats[current];
    await _fetchResponse(chat);
  }
}
