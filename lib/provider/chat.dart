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
  Future<Chat> build() async {
    final models = await ref.watch(modelsNotifierProvider.future);
    final model = models.first.value;
    return Chat()..model = model;
  }

  Future<void> closeStreaming() async {
    final previousState = await future;
    final chat = previousState.copyWith(updatedAt: DateTime.now());
    isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
  }

  Future<void> regenerate(Message message) async {
    final messages = await ref.read(messagesNotifierProvider.future);
    final index = messages.indexWhere((item) => item.id == message.id);
    final userMessage = messages.elementAt(index - 1);
    final notifier = ref.read(messagesNotifierProvider.notifier);
    await notifier.destroy(message);
    send(userMessage.content);
  }

  Future<void> replace(Chat chat) async {
    state = AsyncData(chat);
    await future;
  }

  Future<void> send(String message) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    await _ensurePersistence();
    final messageNotifier = ref.read(messagesNotifierProvider.notifier);
    await messageNotifier.store(message);
    final histories = await ref.read(messagesNotifierProvider.future);
    final messages = histories.map((item) {
      return {'role': item.role, 'content': item.content};
    }).toList();
    final model = await _getModel();
    try {
      final stream = await ChatApi().getCompletion(messages, model: model);
      await for (final token in stream) {
        await messageNotifier.streaming(token);
      }
      await messageNotifier.closeStreaming();
      await store();
    } catch (error) {
      messageNotifier.store(error.toString(), role: 'assistant');
    }
    streamingNotifier.close();
    await _generateTitle(message, model);
  }

  Future<void> store({String? title}) async {
    final previousState = await future;
    final chat = previousState.copyWith(
      title: title,
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    state = AsyncData(chat);
    ref.invalidate(chatsNotifierProvider);
  }

  Future<void> streaming(String token) async {
    final previousState = await future;
    final title = (previousState.title ?? '') + token;
    final chat = previousState.copyWith(title: title);
    state = AsyncData(chat);
  }

  Future<void> updateModel(String model) async {
    final previousState = await future;
    final chat = previousState.copyWith(model: model);
    state = AsyncData(chat);
  }

  Future<void> _ensurePersistence() async {
    final chat = await future;
    if (chat.id.isNegative) await store(title: '');
  }

  Future<void> _generateTitle(String message, String model) async {
    final previousState = await future;
    if (previousState.title?.isNotEmpty == true) return;
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

  Future<String> _getModel() async {
    final chat = await future;
    final model = chat.model;
    if (model.isNotEmpty) return model;
    final models = await ref.read(modelsNotifierProvider.future);
    return models.first.value;
  }
}

@riverpod
class ChatsNotifier extends _$ChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    final queryBuilder = isar.chats.filter().titleIsNotNull();
    return await queryBuilder.sortByUpdatedAt().findAll();
  }

  Future<void> destroy(int id) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(id);
      await isar.messages.filter().chatIdEqualTo(id).deleteAll();
    });
    ref.invalidateSelf();
    final chat = await ref.read(chatNotifierProvider.future);
    if (chat.id == id) ref.invalidate(chatNotifierProvider);
  }
}

@riverpod
class MessagesNotifier extends _$MessagesNotifier {
  @override
  Future<List<Message>> build() async {
    final chat = await ref.watch(chatNotifierProvider.future);
    return await isar.messages.filter().chatIdEqualTo(chat.id).findAll();
  }

  Future<void> closeStreaming() async {
    final messages = await future;
    final message = messages.lastOrNull;
    if (message == null) return;
    await isar.writeTxn(() async {
      await isar.messages.put(message);
    });
  }

  Future<void> destroy(Message message) async {
    final messages = await future;
    final index = messages.indexWhere((item) => item.id == message.id);
    List<Message> removed = [];
    for (var i = index - 1; i < messages.length; i++) {
      removed.add(messages.elementAt(i));
    }
    messages.removeRange(index - 1, messages.length);
    state = AsyncData([...messages]);
    await future;
    isar.writeTxn(() async {
      await isar.messages.deleteAll(removed.map((item) => item.id).toList());
    });
  }

  Future<void> store(String content, {String role = 'user'}) async {
    final chat = await ref.read(chatNotifierProvider.future);
    final message = Message();
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
    final chat = await ref.read(chatNotifierProvider.future);
    message.chatId = chat.id;
    message.content = '${message.content}$token';
    message.role = 'assistant';
    if (messages.last.role == 'assistant') {
      messages.removeLast();
    }
    state = AsyncData([...messages, message]);
  }
}

@riverpod
class SentinelNotifier extends _$SentinelNotifier {
  @override
  Future<Sentinel> build() async {
    final sentinel = await isar.sentinels.where().findFirst();
    if (sentinel != null) return sentinel;
    final defaultSentinel = Sentinel()..name = 'Athena';
    isar.writeTxn(() async {
      isar.sentinels.put(defaultSentinel);
    });
    return defaultSentinel;
  }
}

@riverpod
class SentinelsNotifier extends _$SentinelsNotifier {
  @override
  Future<List<Sentinel>> build() async {
    return await isar.sentinels.where().findAll();
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
