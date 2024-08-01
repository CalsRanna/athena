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

  Future<void> store() async {
    final chat = state.copyWith();
    await isar.writeTxn(() async {
      await isar.chats.put(chat);
    });
    state = chat;
  }
}

@riverpod
class ChatsNotifier extends _$ChatsNotifier {
  @override
  Future<List<Chat>> build() async {
    return await isar.chats.where().findAll();
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
