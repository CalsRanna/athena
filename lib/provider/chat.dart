import 'package:athena/api/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/provider/setting.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  Future<Chat> build(int id, {int? sentinelId}) async {
    final chat = await isar.chats.where().idEqualTo(id).findFirst();
    if (chat != null) return chat;
    final setting = await ref.watch(settingNotifierProvider.future);
    final model = setting.model;
    if (model.isNotEmpty) {
      return Chat()
        ..model = model
        ..sentinelId = sentinelId ?? 0;
    }
    final models = await ref.watch(modelsNotifierProvider.future);
    final firstModel = models.first.value;
    return Chat()
      ..model = firstModel
      ..sentinelId = sentinelId ?? 0;
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

  Future<int> create() async {
    var previousState = await future;
    var chat = previousState.copyWith(
      sentinelId: sentinelId,
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      chat.id = await isar.chats.put(chat);
    });
    state = AsyncData(chat.copyWith(id: chat.id));
    return chat.id;
  }

  Future<void> replace(Chat chat) async {
    state = AsyncData(chat);
    final sentinel =
        await isar.sentinels.filter().idEqualTo(chat.sentinelId).findFirst();
    final athena =
        await isar.sentinels.filter().nameEqualTo('Athena').findFirst();
    var provider = sentinelNotifierProvider(sentinelId ?? 0);
    final notifier = ref.read(provider.notifier);
    notifier.select(sentinel ?? athena ?? Sentinel(), invalidate: false);
    await future;
  }

  Future<void> updateSentinel(Sentinel sentinel) async {
    var previousState = await future;
    final chat = previousState.copyWith(sentinelId: sentinel.id);
    state = AsyncData(chat);
  }

  Future<void> resend(Message message) async {
    var provider = messagesNotifierProvider(id);
    final notifier = ref.read(provider.notifier);
    await notifier.destroy(message);
    send(message.content);
  }

  Future<void> send(String message, {Model? model, Sentinel? sentinel}) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    var messagesProvider = messagesNotifierProvider(id);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    await messagesNotifier.store(message);
    final prompt = await _getPrompt(sentinel: sentinel);
    final system = {'role': 'system', 'content': prompt};
    final histories = await ref.read(messagesProvider.future);
    final modelValue = await _getModel(model: model);
    try {
      final stream = ChatApi().getCompletion(
        messages: [Message.fromJson(system), ...histories],
        model: modelValue,
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
    await _generateTitle(message, modelValue);
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
    final title = (previousState.title) + token;
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
    if (previousState.title.isNotEmpty == true) return;
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

  Future<String> _getModel({Model? model}) async {
    if (model != null) return model.value;
    final chat = await future;
    var provider = modelNotifierProvider(chat.model);
    final chatRelatedModel = await ref.watch(provider.future);
    return chatRelatedModel.value;
  }

  Future<String> _getPrompt({Sentinel? sentinel}) async {
    if (sentinel != null) return sentinel.prompt;
    var chat = await future;
    var sentinelId = chat.sentinelId;
    var provider = sentinelNotifierProvider(sentinelId);
    final chatRelatedSentinel = await ref.read(provider.future);
    return chatRelatedSentinel.prompt;
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
    for (var i = index; i < messages.length; i++) {
      removed.add(messages.elementAt(i));
    }
    messages.removeRange(index, messages.length);
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
