import 'package:athena/creator/global.dart';
import 'package:athena/model/chat.dart';
import 'package:creator/creator.dart';
import 'package:isar/isar.dart';

final chatsEmitter = Emitter<List<Chat>?>(
  (ref, emit) async {
    final isar = ref.watch(isarEmitter.asyncData).data;
    final chats = await isar?.chats.where().findAll();
    emit(chats);
  },
  name: 'chatsEmitter',
);

final chatEmitter = Emitter.arg1<Chat?, Id?>(
  (ref, id, emit) async {
    final isar = ref.watch(isarEmitter.asyncData).data;
    final chat = await isar?.chats.filter().idEqualTo(id ?? 0).findFirst();
    emit(chat);
  },
  name: (id) => 'chatEmitter_$id',
);
