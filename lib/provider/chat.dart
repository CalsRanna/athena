import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/vendor/openai_dart/delta.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  Future<Chat> build(int id) async {
    final chat = await isar.chats.where().idEqualTo(id).findFirst();
    if (chat != null) return chat;
    var providers = await ref.watch(enabledProvidersNotifierProvider.future);
    var provider = providers.firstOrNull ?? schema.Provider();
    var models = await ref.watch(modelsForNotifierProvider(provider.id).future);
    var model = models.firstOrNull ?? Model();
    final sentinel = await ref.watch(sentinelNotifierProvider(0).future);
    return Chat()
      ..modelId = model.id
      ..sentinelId = sentinel.id;
  }
}

@riverpod
class ChatsNotifier extends _$ChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    return await isar.chats.where().sortByUpdatedAtDesc().findAll();
  }

  Future<void> destroy(int id) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(id);
      await isar.messages.filter().chatIdEqualTo(id).deleteAll();
    });
    ref.invalidateSelf();
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> updateChatTitle(String title, {required Chat chat}) async {
    var newChat = chat.copyWith(title: title);
    var chats = await future;
    var index = chats.indexWhere((item) => item.id == chat.id);
    if (index < 0) return;
    chats[index] = newChat;
    state = AsyncData(chats);
  }
}

@riverpod
class MessagesNotifier extends _$MessagesNotifier {
  /// **IMPORTANT** Only called for appending error message
  ///
  /// Appends error message to the last message if its role is 'assistant'.
  /// If the last message is not from the assistant or does not exist,
  /// it stores a new error message with the role of 'assistant'.
  Future<void> append(String error) async {
    final messages = await future;
    final message = messages.lastOrNull;
    if (message?.role != 'assistant') {
      await store(error, role: 'assistant');
    } else {
      message!.content = '${message.content}\n$error';
      await isar.writeTxn(() async {
        await isar.messages.put(message);
      });
    }
    ref.invalidateSelf();
  }

  @override
  Future<List<Message>> build(int chatId) async {
    return await isar.messages.filter().chatIdEqualTo(chatId).findAll();
  }

  Future<void> closeStreaming({String? reference}) async {
    final messages = await future;
    final message = messages.lastOrNull;
    if (message == null) return;
    if (reference != null) message.reference = reference;
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
    ref.invalidateSelf();
  }

  Future<void> destroy(Message message) async {
    final messages = await future;
    final index = messages.indexWhere((item) => item.id == message.id);
    List<Message> removed = [];
    for (var i = index; i < messages.length; i++) {
      removed.add(messages.elementAt(i));
    }
    messages.removeRange(index, messages.length);
    state = AsyncData([...messages]);
    await future;
    await isar.writeTxn(() async {
      await isar.messages.deleteAll(removed.map((item) => item.id).toList());
    });
  }

  Future<void> store(String content, {String role = 'user'}) async {
    final message = Message();
    message.chatId = chatId;
    message.content = content;
    message.role = role;
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
    ref.invalidateSelf();
  }

  Future<void> streaming(
    OverrodeChatCompletionStreamResponseDelta delta,
  ) async {
    final messages = await future;
    var message = messages.last;
    if (message.role == 'user') message = Message()..role = 'assistant';
    message.chatId = chatId;
    message.content = '${message.content}${delta.content}';
    var reasoningContent = delta.reasoningContent ?? '';
    message.reasoningContent = '${message.reasoningContent}$reasoningContent';
    var reasoning = delta.content.isEmpty && reasoningContent.isNotEmpty;
    message.reasoning = reasoning;
    if (reasoning) {
      message.expanded = true;
      message.reasoningUpdatedAt = DateTime.now();
    } else {
      message.expanded = false;
    }
    if (messages.last.role == 'assistant') messages.removeLast();
    state = AsyncData([...messages, message]);
  }
}

@riverpod
class RecentChatsNotifier extends _$RecentChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    return await isar.chats.where().sortByUpdatedAtDesc().limit(5).findAll();
  }
}

@riverpod
class StreamingNotifier extends _$StreamingNotifier {
  @override
  bool build() {
    return false;
  }

  void close() {
    state = false;
  }

  void streaming() {
    state = true;
  }
}
