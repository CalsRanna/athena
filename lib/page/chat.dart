import 'dart:async';

import 'package:athena/creator/account.dart';
import 'package:athena/creator/chat.dart';
import 'package:athena/creator/model.dart';
import 'package:athena/main.dart';
import 'package:athena/model/liaobots_account.dart';
import 'package:athena/model/liaobots_model.dart';
import 'package:athena/provider/liaobots.dart';
import 'package:athena/schema/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.id});
  final int? id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController scrollController;
  late TextEditingController textEditingController;

  bool loading = false;
  bool showFloatingActionButton = false;
  Chat chat = Chat();

  @override
  void initState() {
    super.initState();
    fetchChat();
    scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          showFloatingActionButton =
              scrollController.position.extentBefore != 0;
        });
      });
    textEditingController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    setDefaultModel();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatingActionButton = showFloatingActionButton
        ? Padding(
            padding: const EdgeInsets.only(bottom: 72),
            child: FloatingActionButton.small(
              shape: const CircleBorder(),
              onPressed: scrollToBottom,
              child: const Icon(Icons.arrow_downward_outlined),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          loading ? '对方正在输入...' : chat.title ?? '',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemBuilder: (context, index) => ChatTile(
                message: chat.messages.reversed.elementAt(index),
                onDelete: () => handleDelete(index),
                onEdit: () => handleEdit(index),
                onRetry: () => handleRetry(index),
              ),
              itemCount: chat.messages.length,
              padding: const EdgeInsets.all(16),
              reverse: true,
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 3,
            surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textEditingController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          hintText: 'Ask me anything...',
                          isCollapsed: false,
                          isDense: true,
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        scrollPadding: EdgeInsets.zero,
                        onSubmitted: handleSubmitted,
                        onTapOutside: (event) =>
                            FocusScope.of(context).unfocus(),
                      ),
                    ),
                    SizedBox(width: 16),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                      onPressed: selectModel,
                      icon: Icon(
                        Icons.explore_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Future<void> fetchChat() async {
    if (widget.id != null) {
      final exist = await isar.chats.get(widget.id!);
      setState(() {
        chat = exist?.withGrowableMessages() ?? Chat();
      });
    }
  }

  Future<void> setDefaultModel() async {
    final ref = context.ref;
    final models = ref.read(modelsCreator);
    if (chat.model.value != null) return;
    chat.model.value = models.elementAt(1);
    if (chat.messages.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
        await chat.model.save();
      });
    }
  }

  Future<void> handleDelete(int index) async {
    final realIndex = chat.messages.length - 1 - index;
    setState(() {
      chat.messages.removeRange(realIndex, chat.messages.length);
      if (chat.messages.isEmpty) {
        chat.title = null;
        chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
      } else {
        chat.updatedAt = chat.messages.last.createdAt;
      }
    });
    storeChat();
  }

  void handleEdit(int index) {
    final realIndex = chat.messages.length - 1 - index;
    final message = chat.messages.elementAt(realIndex);
    textEditingController.text = message.content ?? '';
  }

  Future<void> handleRetry(int index) async {
    handleDelete(index);
    await fetchResponse();
  }

  Future<void> handleSubmitted(String value) async {
    final trimmedValue = value.trim().replaceAll('\n', '');
    if (trimmedValue.isEmpty) return;
    final message = Message()
      ..role = 'user'
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..content = trimmedValue;
    setState(() {
      chat.messages.add(message);
      chat.updatedAt = message.createdAt;
    });
    textEditingController.clear();
    await fetchResponse();
    if (chat.title == null) {
      generateTitle(value);
    }
  }

  void selectModel() {
    final models = context.ref.read(modelsCreator);
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemBuilder: (context, index) {
          var selected = false;
          if (chat.model.value == null) {
            selected = true;
          } else {
            selected = models[index].id == chat.model.value?.id;
          }
          return ListTile(
            title: Text(models[index].modelId),
            trailing: selected ? Icon(Icons.check_outlined) : null,
            onTap: () => handleSelect(index),
          );
        },
        itemCount: models.length,
        padding: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Future<void> handleSelect(int index) async {
    final ref = context.ref;
    final navigator = Navigator.of(context);
    final models = ref.read(modelsCreator);
    chat.model.value = models[index];
    await isar.writeTxn(() async {
      chat.model.value = models[index];
      await isar.chats.put(chat);
      await chat.model.save();
    });
    navigator.pop();
  }

  Future<void> fetchResponse() async {
    setState(() {
      loading = true;
      chat.messages.add(Message()..role = 'assistant');
    });
    final logger = Logger();
    try {
      final messages = chat.messages
          .where(
              (message) => message.role != 'error' && message.createdAt != null)
          .toList();
      final limitedMessages = messages
          .map((message) => {'role': message.role, 'content': message.content})
          .toList();
      final model = chat.model.value!;
      final stream = await LiaobotsProvider().getCompletion(
        messages: limitedMessages,
        model: LiaobotsModel.fromJson({
          "id": model.modelId,
          "maxLength": model.maxLength,
          "name": model.name,
          "tokenLimit": model.tokenLimit
        }),
      );
      setState(() {
        chat.messages.last.createdAt = DateTime.now().millisecondsSinceEpoch;
      });
      stream.listen(
        (token) {
          setState(() {
            chat.messages.last.role = 'assistant';
            chat.messages.last.content =
                '${chat.messages.last.content ?? ''}$token';
          });
        },
        onDone: () {
          setState(() {
            chat.updatedAt = DateTime.now().millisecondsSinceEpoch;
            loading = false;
          });
          storeChat();
          updateAccount();
        },
      );
    } catch (error) {
      logger.e(error);
      final message = Message()
        ..role = 'error'
        ..content = error.toString()
        ..createdAt = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        chat.messages.last = message;
        chat.updatedAt = chat.messages.last.createdAt;
        loading = false;
      });
      storeChat();
    }
  }

  Future<void> generateTitle(String value) async {
    final logger = Logger();
    try {
      final model = chat.model.value!;
      final stream = await LiaobotsProvider().getTitle(
        value: value,
        model: LiaobotsModel.fromJson({
          "id": model.modelId,
          "maxLength": model.maxLength,
          "name": model.name,
          "tokenLimit": model.tokenLimit
        }),
      );
      setState(() {
        chat.messages.last.createdAt = DateTime.now().millisecondsSinceEpoch;
      });
      stream.listen(
        (token) {
          setState(() {
            chat.title = '${chat.title ?? ''}$token'.trim().replaceAll('。', '');
          });
        },
        onDone: () {
          storeChat();
          updateAccount();
        },
      );
    } catch (error) {
      logger.e(error);
    }
  }

  Future<void> updateAccount() async {
    final ref = context.ref;
    final response = await LiaobotsProvider().getAccount();
    ref.set(accountCreator, LiaobotsAccount.fromJson(response));
  }

  Future<void> storeChat() async {
    try {
      final ref = context.ref;
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
      });
      final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
      ref.emit(chatsEmitter, chats);
    } catch (error) {
      Logger().e(error);
    }
  }

  void scrollToBottom() {
    Timer(const Duration(milliseconds: 16), () {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    });
  }
}

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.message,
    this.onDelete,
    this.onEdit,
    this.onRetry,
  });
  final Message message;
  final void Function()? onDelete;
  final void Function()? onEdit;
  final void Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: message.role == 'user'
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (message.role != 'user')
          Container(
            decoration: BoxDecoration(
              color: message.role == 'assistant'
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 8, top: 8),
            child: const Icon(Icons.smart_toy_outlined),
          ),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: message.role == 'user'
                  ? Theme.of(context).colorScheme.primaryContainer
                  : message.role == 'assistant'
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.createdAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 10,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(
                                message.createdAt ?? 0)
                            .toString()
                            .substring(0, 16),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      const Spacer(),
                      if (message.role == 'user')
                        GestureDetector(
                          onTap: () => onDelete?.call(),
                          child: Text(
                            '删除对话',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (message.role != 'user')
                        GestureDetector(
                          onTap: () => onRetry?.call(),
                          child: Text(
                            '重试',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        ),
                      if (message.role == 'user')
                        GestureDetector(
                          onTap: () => onEdit?.call(),
                          child: Text(
                            '编辑',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (message.role != 'error')
                        GestureDetector(
                          onTap: () => copy(context, message),
                          child: Text(
                            '复制',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                        )
                    ],
                  ),
                if (message.createdAt != null) const SizedBox(height: 2),
                if (message.createdAt != null)
                  SelectableText(message.content ?? ''),
                if (message.createdAt == null) const Text('正在思考...'),
              ],
            ),
          ),
        ),
        if (message.role == 'user')
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(left: 8, top: 8),
            child: const Icon(Icons.face_outlined),
          ),
      ],
    );
  }

  void copy(BuildContext context, Message message) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: message.content ?? ''));
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('已复制'),
        width: 75,
      ),
    );
  }
}
