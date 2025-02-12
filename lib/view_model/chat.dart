import 'package:athena/api/chat.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/view_model/view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

class ChatViewModel extends ViewModel {
  final WidgetRef ref;
  ChatViewModel(this.ref);

  bool get streaming => ref.read(streamingNotifierProvider);

  Future<Chat> createChat({
    required Model model,
    required Sentinel sentinel,
  }) async {
    var timestamp = DateTime.now();
    var chat = Chat()
      ..modelId = model.id
      ..title = 'New Chat'
      ..sentinelId = sentinel.id
      ..createdAt = timestamp
      ..updatedAt = timestamp;
    await isar.writeTxn(() async {
      chat.id = await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return chat;
  }

  Future<void> destroyChat(Chat chat) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(chat.id);
      await isar.messages.filter().chatIdEqualTo(chat.id).deleteAll();
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<String?> generateChatTitle(
    String text, {
    required Chat chat,
    required Model model,
  }) async {
    var provider = providerNotifierProvider(model.providerId);
    var aiProvider = await ref.read(provider.future);
    if (chat.title.isNotEmpty && chat.title != 'New Chat') return null;
    var title = '';
    try {
      final titleTokens = ChatApi().getTitle(
        text,
        model: model,
        provider: aiProvider,
      );
      await for (final token in titleTokens) {
        title += token;
      }
    } catch (error) {
      title = '';
    }
    var copiedChat = chat.copyWith(
      title: title.trim(),
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return title;
  }

  Future<Chat?> getFirstChat() async {
    var chats = await ref.read(chatsNotifierProvider.future);
    if (chats.isEmpty) return null;
    return chats.first;
  }

  Future<Model?> getFirstEnabledModel() async {
    var result = await ref.read(groupedEnabledModelsNotifierProvider.future);
    if (result.isEmpty) return null;
    var entry = result.entries.first;
    var models = entry.value;
    if (models.isEmpty) return null;
    return models.first;
  }

  Future<Sentinel?> getFirstSentinel() async {
    var sentinels = await ref.read(sentinelsNotifierProvider.future);
    if (sentinels.isEmpty) return null;
    return sentinels.first;
  }

  Future<Model?> getModel(int id) async {
    return await isar.models.filter().idEqualTo(id).findFirst();
  }

  Future<Sentinel?> getSentinel(int id) async {
    return await isar.sentinels.filter().idEqualTo(id).findFirst();
  }

  void navigateSettingPage(BuildContext context) {
    DesktopSettingProviderRoute().push(context);
  }

  Future<void> resendMessage(
    Message message, {
    required Chat chat,
    required Model model,
    required Sentinel sentinel,
  }) async {
    var builder = isar.messages.filter().chatIdEqualTo(chat.id);
    final messages = await builder.findAll();
    final index = messages.indexWhere((item) => item.id == message.id);
    List<Message> removed = [];
    for (var i = index; i < messages.length; i++) {
      removed.add(messages.elementAt(i));
    }
    messages.removeRange(index, messages.length);
    isar.writeTxn(() async {
      await isar.messages.deleteAll(removed.map((item) => item.id).toList());
    });
    ref.invalidate(messagesNotifierProvider(chat.id));
    await sendMessage(
      message.content,
      chat: chat,
      model: model,
      sentinel: sentinel,
    );
  }

  Future<Chat> selectModel(Model model, {required Chat chat}) async {
    var copiedChat = chat.copyWith(
      modelId: model.id,
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return chat;
  }

  Future<Chat> selectSentinel(Sentinel sentinel, {required Chat chat}) async {
    var copiedChat = chat.copyWith(
      sentinelId: sentinel.id,
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return chat;
  }

  Future<void> sendMessage(
    String text, {
    required Chat chat,
    required Model model,
    required Sentinel sentinel,
  }) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    final message = Message();
    message.chatId = chat.id;
    message.content = text;
    message.role = 'user';
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
    ref.invalidate(messagesNotifierProvider(chat.id));
    final system = {'role': 'system', 'content': sentinel.prompt};
    var messagesProvider = messagesNotifierProvider(chat.id);
    final histories = await ref.read(messagesProvider.future);
    var provider = providerNotifierProvider(model.providerId);
    var aiProvider = await ref.read(provider.future);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    try {
      final stream = ChatApi().getCompletion(
        messages: [Message.fromJson(system), ...histories],
        model: model,
        provider: aiProvider,
      );
      await for (final token in stream) {
        await messagesNotifier.streaming(token);
      }
      await messagesNotifier.closeStreaming();
      await isar.writeTxn(() async {
        await isar.chats.put(chat.copyWith(updatedAt: DateTime.now()));
      });
      ref.invalidate(chatsNotifierProvider);
      ref.invalidate(recentChatsNotifierProvider);
    } catch (error) {
      messagesNotifier.append(error.toString());
    }
    streamingNotifier.close();
  }
}
