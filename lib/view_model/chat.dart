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

  Future<Chat> createChat({Sentinel? sentinel}) async {
    var model = await getFirstEnabledModel();
    var firstSentinel = await getFirstSentinel();
    var timestamp = DateTime.now();
    var chat = Chat()
      ..title = 'New Chat'
      ..modelId = model.id
      ..sentinelId = sentinel?.id ?? firstSentinel.id
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
    var chats = await isar.chats.count();
    if (chats <= 1) return;
    await isar.writeTxn(() async {
      await isar.chats.delete(chat.id);
      await isar.messages.filter().chatIdEqualTo(chat.id).deleteAll();
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<Chat> getFirstChat() async {
    var chats = await ref.read(chatsNotifierProvider.future);
    if (chats.isEmpty) return Chat();
    return chats.first;
  }

  Future<Model> getFirstEnabledModel() async {
    var model = await ref.read(chatModelNotifierProvider.future);
    if (model.id != 0) return model;
    var result = await ref.read(groupedEnabledModelsNotifierProvider.future);
    if (result.isEmpty) return Model();
    var entry = result.entries.first;
    var models = entry.value;
    if (models.isEmpty) return Model();
    return models.first;
  }

  Future<Sentinel> getFirstSentinel() async {
    var sentinels = await ref.read(sentinelsNotifierProvider.future);
    if (sentinels.isEmpty) return Sentinel();
    return sentinels.first;
  }

  Future<Model> getModel(int id) async {
    var model = await isar.models.filter().idEqualTo(id).findFirst();
    return model ?? Model();
  }

  Future<Sentinel> getSentinel(int id) async {
    var sentinel = await isar.sentinels.filter().idEqualTo(id).findFirst();
    return sentinel ?? Sentinel();
  }

  Future<bool> hasModel() async {
    var models = await ref.read(groupedEnabledModelsNotifierProvider.future);
    return models.isNotEmpty;
  }

  Future<void> initChats() async {
    var count = await isar.chats.count();
    if (count > 0) return;
    await createChat();
  }

  void navigateSettingPage(BuildContext context) {
    DesktopSettingProviderRoute().push(context);
  }

  Future<String> renameChat(Chat chat) async {
    var messages = await ref.read(messagesNotifierProvider(chat.id).future);
    if (messages.isEmpty) return 'New Chat';
    var model = await ref.read(chatNamingModelNotifierProvider.future);
    var provider = providerNotifierProvider(model.providerId);
    var aiProvider = await ref.read(provider.future);
    var notifier = ref.read(chatsNotifierProvider.notifier);
    var title = '';
    try {
      final response = ChatApi().getTitle(
        messages.first.content,
        model: model,
        provider: aiProvider,
      );
      await for (final token in response) {
        title += token;
        title = title.replaceAll(' ', '').replaceAll('\n', '');
        notifier.updateChatTitle(title, chat: chat);
      }
    } catch (error) {
      title = error.toString().replaceAll(' ', '').replaceAll('\n', '');
      notifier.updateChatTitle(title, chat: chat);
    }
    var copiedChat = chat.copyWith(title: title);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return title;
  }

  Future<void> resendMessage(
    Message message, {
    required Chat chat,
    Model? model,
    Sentinel? sentinel,
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
    var copiedChat = chat.copyWith(modelId: model.id);
    await isar.writeTxn(() async {
      await isar.chats.put(copiedChat);
    });
    ref.invalidate(chatNotifierProvider(chat.id));
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
    return chat;
  }

  Future<Chat> selectSentinel(Sentinel sentinel, {required Chat chat}) async {
    var copiedChat = chat.copyWith(sentinelId: sentinel.id);
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
    Model? model,
    Sentinel? sentinel,
  }) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    var defaultModel =
        await ref.read(modelNotifierProvider(chat.modelId).future);
    var realUsedModel = model ?? defaultModel;
    var defaultSentinel =
        await ref.read(sentinelNotifierProvider(chat.sentinelId).future);
    var realSentinel = sentinel ?? defaultSentinel;
    final userMessage = Message();
    userMessage.chatId = chat.id;
    userMessage.content = text;
    userMessage.role = 'user';
    await isar.writeTxn(() async {
      await isar.messages.put(userMessage);
    });
    ref.invalidate(messagesNotifierProvider(chat.id));
    final system = {'role': 'system', 'content': realSentinel.prompt};
    var messagesProvider = messagesNotifierProvider(chat.id);
    final histories = await ref.read(messagesProvider.future);
    var provider = providerNotifierProvider(realUsedModel.providerId);
    var aiProvider = await ref.read(provider.future);
    var messagesNotifier = ref.read(messagesProvider.notifier);
    try {
      final response = ChatApi().getCompletion(
        messages: [Message.fromJson(system), ...histories],
        model: realUsedModel,
        provider: aiProvider,
      );
      final assistantMessage = Message();
      assistantMessage.chatId = chat.id;
      assistantMessage.role = 'assistant';
      await isar.writeTxn(() async {
        await isar.messages.put(assistantMessage);
      });
      ref.invalidate(messagesNotifierProvider(chat.id));
      await for (final delta in response) {
        await messagesNotifier.streaming(delta);
      }
      await messagesNotifier.closeStreaming();
      // Can not use the chat from params anymore cause the chat's title maybe
      // changed in the meantime
      var newChat = await isar.chats.filter().idEqualTo(chat.id).findFirst();
      var copiedChat = (newChat ?? Chat()).copyWith(updatedAt: DateTime.now());
      await isar.writeTxn(() async {
        await isar.chats.put(copiedChat);
      });
      ref.invalidate(chatsNotifierProvider);
      ref.invalidate(recentChatsNotifierProvider);
    } catch (error) {
      messagesNotifier.append(error.toString());
    }
    streamingNotifier.close();
  }
}
