import 'package:athena/api/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  Future<Chat> build(int id, {int? sentinelId}) async {
    final sentinel = await ref.read(sentinelNotifierProvider.future);
    final setting = await ref.watch(settingNotifierProvider.future);
    final model = setting.model;
    if (model.isNotEmpty) {
      return Chat()
        ..model = model
        ..sentinelId = sentinel.id;
    }
    final models = await ref.watch(modelsNotifierProvider.future);
    final firstModel = models.first.value;
    return Chat()
      ..model = firstModel
      ..sentinelId = sentinel.id;
  }

  Future<void> closeStreaming() async {
    final previousState = await future;
    final chat = previousState.copyWith(updatedAt: DateTime.now());
    isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> regenerate(Message message) async {
    // final messages = await ref.read(messagesNotifierProvider.future);
    // final index = messages.indexWhere((item) => item.id == message.id);
    // final userMessage = messages.elementAt(index - 1);
    // final notifier = ref.read(messagesNotifierProvider.notifier);
    // await notifier.destroy(message);
    // send(userMessage.content);
  }

  Future<void> replace(Chat chat) async {
    state = AsyncData(chat);
    final sentinel =
        await isar.sentinels.filter().idEqualTo(chat.sentinelId).findFirst();
    final athena =
        await isar.sentinels.filter().nameEqualTo('Athena').findFirst();
    final notifier = ref.read(sentinelNotifierProvider.notifier);
    notifier.select(sentinel ?? athena ?? Sentinel(), invalidate: false);
    await future;
  }

  Future<void> send(String message) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    final messagesNotifier = ref.read(messagesNotifierProvider(id).notifier);
    await messagesNotifier.store(message);
    final prompt = await _getPrompt();
    final system = {'role': 'system', 'content': prompt};
    final histories = await ref.read(messagesNotifierProvider(id).future);
    final model = await _getModel();
    try {
      final stream = ChatApi().getCompletion(
        messages: [Message.fromJson(system), ...histories],
        model: model,
      );
      await for (final token in stream) {
        await messagesNotifier.streaming(token);
      }
      await messagesNotifier.closeStreaming();
      await store();
    } catch (error) {
      messagesNotifier.append(error.toString());
    }
    streamingNotifier.close();
    await _generateTitle(message, model);
  }

  Future<int> create(String message) async {
    var now = DateTime.now();
    var chat = Chat()
      ..createdAt = now
      ..sentinelId = sentinelId ?? 0
      ..title = ''
      ..updatedAt = now;
    await isar.writeTxn(() async {
      chat.id = await isar.chats.put(chat);
    });
    return chat.id;
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
    ref.invalidate(recentChatsNotifierProvider);
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

  Future<void> _generateTitle(String message, String model) async {
    final previousState = await future;
    if (previousState.title?.isNotEmpty == true) return;
    try {
      final titleTokens = ChatApi().getTitle(message, model: model);
      await for (final token in titleTokens) {
        streaming(token);
      }
      closeStreaming();
    } catch (error) {
      store(title: '');
    }
  }

  Future<String> _getModel() async {
    final chat = await future;
    final model = chat.model;
    if (model.isNotEmpty) return model;
    final models = await ref.read(modelsNotifierProvider.future);
    return models.first.value;
  }

  Future<String> _getPrompt() async {
    final sentinel = await ref.read(sentinelNotifierProvider.future);
    return sentinel.prompt;
  }
}

@riverpod
class ChatsNotifier extends _$ChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    final queryBuilder = isar.chats.filter().titleIsNotNull();
    return await queryBuilder.sortByUpdatedAtDesc().findAll();
  }

  Future<void> destroy(int id) async {
    await isar.writeTxn(() async {
      await isar.chats.delete(id);
      await isar.messages.filter().chatIdEqualTo(id).deleteAll();
    });
    ref.invalidateSelf();
    // final chat = await ref.read(chatNotifierProvider.future);
    // if (chat.id == id) ref.invalidate(chatNotifierProvider);
  }
}

@riverpod
class RecentChatsNotifier extends _$RecentChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    final queryBuilder = isar.chats.filter().titleIsNotNull();
    return await queryBuilder.sortByUpdatedAtDesc().limit(5).findAll();
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
    final message = Message();
    message.chatId = chatId;
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
    message.chatId = chatId;
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

  void select(Sentinel sentinel, {bool invalidate = true}) {
    state = AsyncData(sentinel);
    if (!invalidate) return;
    ref.invalidate(chatNotifierProvider);
  }
}

@riverpod
class SentinelsNotifier extends _$SentinelsNotifier {
  @override
  Future<List<Sentinel>> build() async {
    return await isar.sentinels.where().findAll();
  }

  Future<void> destroy(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.delete(sentinel.id);
    });
    ref.invalidateSelf();
  }

  Future<void> store(Sentinel sentinel) async {
    await isar.writeTxn(() async {
      await isar.sentinels.put(sentinel);
    });
    ref.invalidateSelf();
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
