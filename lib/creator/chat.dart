import 'package:athena/main.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:isar/isar.dart';

final chatsEmitter = Emitter<List<Chat>?>(
  (ref, emit) async {
    final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
    emit(chats);
  },
  name: 'chatsEmitter',
);

final chatsCreator = Creator<List<Chat>>.value([], name: 'chatsCreator');

final modelCreator = Creator<String>.value('gpt-4', name: 'modelCreator');
