import 'package:athena/main.dart';
import 'package:athena/model/chat.dart';
import 'package:creator/creator.dart';
import 'package:isar/isar.dart';

final chatsEmitter = Emitter<List<Chat>?>(
  (ref, emit) async {
    final chats = await isar.chats.where().findAll();
    emit(chats);
  },
  name: 'chatsEmitter',
);
