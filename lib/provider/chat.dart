import 'package:athena/api/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  Chat build() {
    return Chat();
  }

  void select(Chat chat) {
    state = chat;
  }

  Future<void> store({String? title}) async {
    final chat = state.copyWith(title: title, updatedAt: DateTime.now());
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    state = chat;
    ref.invalidate(chatsNotifierProvider);
  }

  Future<void> send(String message, {String? model}) async {
    if (state.id.isNegative) await store();
    final messageNotifier = ref.read(messagesNotifierProvider.notifier);
    await messageNotifier.store(message);
    final histories = await ref.read(messagesNotifierProvider.future);
    final messages = histories.map((item) {
      return {'role': item.role, 'content': item.content};
    }).toList();
    final models = await ref.read(modelsNotifierProvider.future);
    model ??= models.first.value;
    try {
      final stream = await ChatApi().getCompletion(messages, model: model);
      await for (final token in stream) {
        await messageNotifier.streaming(token);
      }
      await messageNotifier.closeStreaming();
      await store();
    } catch (error) {
      messageNotifier.store(error.toString());
    }
    if (state.title != null) return;
    try {
      final titleTokens = await ChatApi().getTitle(message, model: model);
      await for (final token in titleTokens) {
        streaming(token);
      }
      closeStreaming();
    } catch (error) {
      store(title: error.toString());
    }
  }

  void streaming(String token) {
    final title = (state.title ?? '') + token;
    state = state.copyWith(title: title);
  }

  void closeStreaming() {
    state = state.copyWith(updatedAt: DateTime.now());
    isar.writeTxn(() async {
      await isar.chats.put(state);
    });
    ref.invalidate(chatsNotifierProvider);
  }
}

@riverpod
class ChatsNotifier extends _$ChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    return await isar.chats.filter().titleIsNotNull().findAll();
  }

  Future<void> select(int index) async {
    final chats = await future;
    final notifier = ref.read(chatNotifierProvider.notifier);
    notifier.select(chats[index]);
  }

  Future<void> destroy(int id) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(id);
    });
    ref.invalidateSelf();
    final chat = ref.read(chatNotifierProvider);
    if (chat.id == id) ref.invalidate(chatNotifierProvider);
  }
}

@riverpod
class MessagesNotifier extends _$MessagesNotifier {
  @override
  Future<List<Message>> build() async {
    final chat = ref.watch(chatNotifierProvider);
    return await isar.messages.filter().chatIdEqualTo(chat.id).findAll();
  }

  Future<void> store(String content, {String role = 'user'}) async {
    final message = Message();
    final chat = ref.read(chatNotifierProvider);
    message.chatId = chat.id;
    message.content = content;
    message.role = role;
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
    ref.invalidateSelf();
  }

  Future<void> streaming(String token) async {
    final messages = await future;
    var message = messages.last;
    if (message.role == 'user') message = Message();
    final chat = ref.read(chatNotifierProvider);
    message.chatId = chat.id;
    message.content = '${message.content}$token';
    message.role = 'assistant';
    if (messages.last.role == 'assistant') {
      messages.removeLast();
    }
    state = AsyncData([...messages, message]);
  }

  Future<void> closeStreaming() async {
    final messages = await future;
    final message = messages.lastOrNull;
    if (message == null) return;
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
  }
}
