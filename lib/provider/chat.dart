import 'package:athena/api/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/provider.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/provider.dart' as schema;
import 'package:athena/schema/sentinel.dart';
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

  Future<int> create({Model? model, Sentinel? sentinel}) async {
    var modelProvider = modelNotifierProvider(model?.id ?? 0);
    var wrappedModel = await ref.read(modelProvider.future);
    var sentinelProvider = sentinelNotifierProvider(sentinel?.id ?? 0);
    var wrappedSentinel = await ref.read(sentinelProvider.future);
    var previousState = await future;
    var chat = previousState.copyWith(
      modelId: wrappedModel.id,
      sentinelId: wrappedSentinel.id,
      updatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      chat.id = await isar.chats.put(chat);
    });
    state = AsyncData(chat.copyWith(id: chat.id));
    return chat.id;
  }

  Future<void> resend(
    Message message, {
    required Model model,
    required Sentinel sentinel,
  }) async {
    var messageProvider = messagesNotifierProvider(id);
    final notifier = ref.read(messageProvider.notifier);
    await notifier.destroy(message);
    send(message.content, model: model, sentinel: sentinel);
  }

  Future<void> send(
    String message, {
    required Model model,
    required Sentinel sentinel,
  }) async {
    final streamingNotifier = ref.read(streamingNotifierProvider.notifier);
    streamingNotifier.streaming();
    var messagesProvider = messagesNotifierProvider(id);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    await messagesNotifier.store(message);
    final prompt = await _getPrompt();
    final system = {'role': 'system', 'content': prompt};
    final histories = await ref.read(messagesProvider.future);
    var provider = await _getProvider(model.providerId);
    try {
      final stream = ChatApi().getCompletion(
        messages: [Message.fromJson(system), ...histories],
        model: model,
        provider: provider,
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
    await _generateTitle(message, model: model);
  }

  Future<void> store({String? title}) async {
    final previousState = await future;
    final chat = previousState.copyWith(
      title: title,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(chat);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> updateModel(Model model) async {
    final previousState = await future;
    final chat = previousState.copyWith(modelId: model.id);
    state = AsyncData(chat);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> updateSentinel(Sentinel sentinel) async {
    var previousState = await future;
    final chat = previousState.copyWith(sentinelId: sentinel.id);
    state = AsyncData(chat);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> updateTitle(String title) async {
    final previousState = await future;
    final chat = previousState.copyWith(title: title);
    state = AsyncData(chat);
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    ref.invalidate(chatsNotifierProvider);
    ref.invalidate(recentChatsNotifierProvider);
  }

  Future<void> _generateTitle(String message, {required Model model}) async {
    final previousState = await future;
    if (previousState.title.isNotEmpty == true) return;
    var provider = await _getProvider(model.id);
    var title = '';
    try {
      final titleTokens = ChatApi().getTitle(
        message,
        model: model,
        provider: provider,
      );
      await for (final token in titleTokens) {
        title += token;
      }
    } catch (error) {
      title = '';
    }
    store(title: title.trim());
  }

  Future<Model> _getModel() async {
    final chat = await future;
    var provider = modelNotifierProvider(chat.modelId);
    return await ref.read(provider.future);
  }

  Future<String> _getPrompt() async {
    var chat = await future;
    var sentinelId = chat.sentinelId;
    var provider = sentinelNotifierProvider(sentinelId);
    final chatRelatedSentinel = await ref.read(provider.future);
    return chatRelatedSentinel.prompt;
  }

  Future<schema.Provider> _getProvider(int providerId) async {
    var provider = providerNotifierProvider(providerId);
    return await ref.read(provider.future);
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
