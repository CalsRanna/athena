import 'package:athena/main.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

final chatsEmitter = Emitter<List<Chat>?>(
  (ref, emit) async {
    final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
    emit(chats);
  },
  name: 'chatsEmitter',
);

final chatsCreator = Creator<List<Chat>>.value([], name: 'chatsCreator');

final currentChatCreator = Creator<int?>.value(
  null,
  name: 'currentChatCreator',
);

final scrollControllerCreator = Creator<ScrollController>.value(
  ScrollController(),
  name: 'scrollControllerCreator',
);

final streamingCreator = Creator<bool>.value(false, name: 'streamingCreator');

final modelCreator = Creator<String>.value('gpt-4', name: 'modelCreator');
