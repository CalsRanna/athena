import 'dart:async';

import 'package:athena/extension/date_time.dart';
import 'package:athena/main.dart';
import 'package:athena/model/liaobots_account.dart';
import 'package:athena/model/liaobots_model.dart';
import 'package:athena/provider/liaobots.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:markdown_widget/markdown_widget.dart';

class Desktop extends StatefulWidget {
  const Desktop({super.key});

  @override
  State<Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<Desktop> {
  List<Chat> chats = [];
  List<Model> models = [];
  Chat chat = Chat();
  int current = 0;
  bool showFloatingActionButton = false;
  LiaobotsAccount account =
      LiaobotsAccount(amount: 0, balance: 0, gpt4: 0, expireDate: 0);
  bool streaming = false;
  late ScrollController scrollController;
  late TextEditingController textEditingController;
  late FocusNode focusNode;

  bool get showLogo => chat.messages.isEmpty;

  @override
  void initState() {
    super.initState();
    init();
    getChats();
    updateModels();
    updateAccount();
  }

  @override
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void init() async {
    scrollController = ScrollController();
    scrollController.addListener(() {
      setState(() {
        showFloatingActionButton = scrollController.position.extentBefore != 0;
      });
    });
    textEditingController = TextEditingController();
    focusNode = FocusNode();
  }

  void getChats() async {
    final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
    setState(() {
      this.chats = chats;
    });
  }

  Future<void> updateModels() async {
    var models = await isar.models.where().findAll();
    if (models.isEmpty) {
      try {
        final liaobotsModels = await LiaobotsProvider().getModels();
        models = liaobotsModels
            .map((model) => Model()
              ..maxLength = model.maxLength
              ..modelId = model.id
              ..name = model.name
              ..tokenLimit = model.tokenLimit)
            .toList();
        await isar.writeTxn(() async {
          await isar.models.putAll(models);
        });
        setState(() {
          this.models = models;
          chat.model.value = models[0];
        });
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } else {
      setState(() {
        this.models = models;
        chat.model.value = models[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final textTheme = theme.textTheme;
    final displayLarge = textTheme.displayLarge;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _ChatList(
                account: account,
                chats: chats,
                currentChatId: chat.id,
                onCreated: createChat,
                onDeleted: deleteChat,
                onSelected: selectChat,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (models.isNotEmpty)
                        _ModelSwitcher(
                          current: current,
                          models: models,
                          onChange: handleSelect,
                        ),
                      if (models.isNotEmpty) SizedBox(height: 16),
                      Expanded(
                        child: showLogo
                            ? Center(
                                child: Text(
                                  'Athena',
                                  style: displayLarge?.copyWith(
                                    color: onSurface.withOpacity(0.15),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemBuilder: (context, index) {
                                  final message =
                                      chat.messages.reversed.elementAt(index);
                                  return _MessageTile(
                                    message: message,
                                    onRegenerated: () => handleRetry(index),
                                    onEdited: () => handleEdit(index),
                                    onDeleted: () => handleDelete(index),
                                  );
                                },
                                itemCount: chat.messages.length,
                                padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
                                reverse: true,
                              ),
                      ),
                      _Input(
                        controller: textEditingController,
                        focusNode: focusNode,
                        streaming: streaming,
                        onSubmitted: handleSubmitted,
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          if (showFloatingActionButton)
            _FloatingButton(onPressed: scrollToBottom),
        ],
      ),
    );
  }

  void createChat() {
    setState(() {
      chat = Chat();
      chat.model.value = models[0];
      current = 0;
    });
    textEditingController.clear();
    focusNode.requestFocus();
  }

  void deleteChat(int index) async {
    final chat = chats.removeAt(index);
    setState(() {
      chats = chats;
      this.chat = Chat();
      current = 0;
    });
    try {
      await isar.writeTxn(() async {
        await isar.chats.delete(chat.id);
      });
    } catch (error) {
      Logger().e(error);
    }
  }

  void selectChat(int index) {
    scrollToBottom();
    setState(() {
      chat = chats[index].withGrowableMessages();
      var modelIndex = models
          .indexWhere((model) => chat.model.value?.modelId == model.modelId);
      current = modelIndex >= 0 ? modelIndex : 0;
    });
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
    focusNode.requestFocus();
  }

  Future<void> handleRetry(int index) async {
    setState(() {
      streaming = true;
    });
    handleDelete(index);
    await fetchResponse();
  }

  Future<void> handleSubmitted(String value) async {
    setState(() {
      streaming = true;
    });
    final message = Message()
      ..role = 'user'
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..content = value;
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

  Future<void> fetchResponse() async {
    scrollToBottom();
    setState(() {
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
      final model = chat.model.value ?? models[0];
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
            streaming = false;
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
        streaming = false;
      });
      storeChat();
    }
  }

  Future<void> generateTitle(String value) async {
    final logger = Logger();
    try {
      final model = chat.model.value ?? models[0];
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
    final response = await LiaobotsProvider().getAccount();
    setState(() {
      account = LiaobotsAccount.fromJson(response);
    });
  }

  Future<void> storeChat() async {
    try {
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
        await chat.model.save();
      });
      final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
      setState(() {
        this.chats = chats;
      });
    } catch (error) {
      Logger().e(error);
    }
  }

  Future<void> handleSelect(int index) async {
    setState(() {
      current = index;
      chat.model.value = models[index];
    });
    if (chat.messages.isNotEmpty) {
      await isar.writeTxn(() async {
        chat.model.value = models[index];
        await isar.chats.put(chat);
        await chat.model.save();
      });
    }
  }

  void scrollToBottom() {
    Timer(const Duration(milliseconds: 16), () {
      try {
        scrollController.animateTo(
          scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutQuart,
        );
      } catch (error) {
        Logger().e(error);
      }
    });
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.account,
    required this.chats,
    this.currentChatId,
    this.onCreated,
    this.onDeleted,
    this.onSelected,
  });

  final LiaobotsAccount account;
  final List<Chat> chats;
  final int? currentChatId;
  final void Function()? onCreated;
  final void Function(int)? onDeleted;
  final void Function(int)? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.fromLTRB(8, 28, 8, 8),
      width: 256,
      child: Column(
        children: [
          _CreateChatButton(onTap: onCreated),
          SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemBuilder: (context, index) {
                return _ChatTile(
                  active: chats[index].id == currentChatId,
                  chat: chats[index],
                  onDelete: () => onDeleted?.call(index),
                  onTap: () => onSelected?.call(index),
                );
              },
              itemCount: chats.length,
              separatorBuilder: (context, index) {
                return SizedBox(height: 8);
              },
            ),
          ),
          _AccountInformation(balance: account.balance, discount: account.gpt4)
        ],
      ),
    );
  }
}

class _CreateChatButton extends StatelessWidget {
  const _CreateChatButton({required this.onTap});

  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;
    final textTheme = theme.textTheme;
    final titleSmall = textTheme.titleSmall;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: onPrimary.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(8),
                ),
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20, color: onPrimary),
                    SizedBox(width: 8),
                    Text(
                      'New Chat',
                      style: titleSmall?.copyWith(color: onPrimary),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    this.active = false,
    required this.chat,
    this.onDelete,
    this.onTap,
  });

  final bool active;
  final Chat chat;
  final void Function()? onDelete;
  final void Function()? onTap;

  String get title => chat.title ?? '';

  String get updatedAt {
    if (chat.updatedAt == null) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(chat.updatedAt!);
    return dateTime.toHumanReadableString();
  }

  IconData get icon {
    switch (chat.model.value?.name) {
      case 'GPT-3.5-16k':
        return Icons.chat_bubble_outline;
      case 'GPT-4':
        return Icons.chat_bubble;
      case 'claude-v1.3':
        return Icons.comment_bank_outlined;
      case 'claude-instant-100k':
        return Icons.comment_bank;
      case 'claude-2-100k':
        return Icons.reviews;
      default:
        return Icons.announcement_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.inversePrimary;
    final onPrimary = colorScheme.onPrimary;
    final textTheme = theme.textTheme;
    final titleMedium = textTheme.titleMedium;
    final titleSmall = textTheme.titleSmall;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? primary : null,
          ),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: onPrimary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleMedium?.copyWith(color: onPrimary),
                ),
              ),
              if (active)
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete, size: 20, color: onPrimary),
                ),
              if (!active)
                Text(
                  updatedAt,
                  style: titleSmall?.copyWith(
                    color: onPrimary.withOpacity(0.5),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountInformation extends StatelessWidget {
  const _AccountInformation({this.balance = 0, this.discount = 0});

  final double balance;
  final int discount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;
    final textTheme = theme.textTheme;
    final bodyMedium = textTheme.bodyMedium;

    return Container(
      alignment: Alignment.center,
      height: 48,
      width: 256,
      child: Text(
        '¥$balance/$discount',
        style: bodyMedium?.copyWith(color: onPrimary),
      ),
    );
  }
}

class _ModelSwitcher extends StatefulWidget {
  const _ModelSwitcher({this.current = 0, required this.models, this.onChange});

  final int current;
  final List<Model> models;
  final void Function(int)? onChange;

  @override
  State<StatefulWidget> createState() => __ModelSwitcherState();
}

class __ModelSwitcherState extends State<_ModelSwitcher>
    with SingleTickerProviderStateMixin {
  late final controller;
  double offset = 0;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(milliseconds: 450),
      upperBound: widget.models.length.toDouble(),
      vsync: this,
    );
    controller.addListener(() {
      setState(() {
        offset = controller.value * 150;
      });
    });
    controller.animateTo(widget.current.toDouble());
  }

  @override
  void didUpdateWidget(_ModelSwitcher oldWidget) {
    controller.animateTo(widget.current.toDouble());
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      padding: EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            left: offset,
            width: 150,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Text(''),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.models.length, (index) {
              return _ModelSwitcherTile(
                name: widget.models[index].name,
                onTap: () => handleTap(index),
              );
            }),
          )
        ],
      ),
    );
  }

  void handleTap(int index) {
    controller.animateTo(index.toDouble());
    widget.onChange?.call(index);
  }
}

class _ModelSwitcherTile extends StatelessWidget {
  const _ModelSwitcherTile({required this.name, this.onTap});

  final String name;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          alignment: Alignment.center,
          width: 150,
          padding: EdgeInsets.all(12),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    this.onDeleted,
    this.onEdited,
    this.onRegenerated,
  });

  final Message message;
  final void Function()? onDeleted;
  final void Function()? onEdited;
  final void Function()? onRegenerated;

  @override
  Widget build(BuildContext context) {
    if (message.content == null) {
      return SizedBox();
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(4, 4),
          )
        ],
        color: Theme.of(context).colorScheme.surface,
      ),
      margin: EdgeInsets.only(bottom: 8, top: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          MarkdownWidget(
            config: MarkdownConfig(configs: [
              PreConfig(
                wrapper: (child, code) {
                  return Stack(children: [child, _CopyButton(code: code)]);
                },
              ),
            ]),
            data: message.content ?? '',
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
          ),
          if (message.role == 'user')
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  TextButton(onPressed: onEdited, child: Text('编辑')),
                  SizedBox(width: 4),
                  TextButton(
                    onPressed: onDeleted,
                    child: Text(
                      '删除',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (message.role != 'user')
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  ElevatedButton(onPressed: onRegenerated, child: Text('重新生成')),
                  SizedBox(width: 4),
                  TextButton(onPressed: () => copy(context), child: Text('复制')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryContainer = colorScheme.primaryContainer;
    final onPrimaryContainer = colorScheme.onPrimaryContainer;
    await Clipboard.setData(ClipboardData(text: message.content ?? ''));
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: primaryContainer,
        behavior: SnackBarBehavior.floating,
        content: Text('已复制', style: TextStyle(color: onPrimaryContainer)),
        width: 75,
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code});

  final String code;

  @override
  State<_CopyButton> createState() => __CopyButtonState();
}

class __CopyButtonState extends State<_CopyButton> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      top: 16,
      child: IconButton(
        onPressed: copied ? null : handlePressed,
        icon: AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          child: copied
              ? Icon(Icons.check_outlined, size: 20)
              : Icon(Icons.content_copy_outlined, size: 20),
        ),
      ),
    );
  }

  void handlePressed() async {
    final data = ClipboardData(text: widget.code);
    await Clipboard.setData(data);
    setState(() {
      copied = true;
    });
    await Future.delayed(Duration(seconds: 2));
    setState(() {
      copied = false;
    });
  }
}

class _Input extends StatefulWidget {
  const _Input({
    this.controller,
    this.focusNode,
    this.streaming = false,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool streaming;
  final void Function(String)? onSubmitted;

  @override
  State<_Input> createState() => __InputState();
}

class __InputState extends State<_Input> {
  bool shift = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outline = colorScheme.outline;
    final primary = colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: outline.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.fromLTRB(32, 8, 32, 0),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: handleKey,
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Ask me anything',
                ),
                focusNode: widget.focusNode,
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),
          SizedBox(width: 16),
          if (widget.streaming)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outline.withOpacity(0.25),
              ),
            ),
          if (!widget.streaming)
            GestureDetector(
              onTap: handleTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(
                  Icons.send,
                  color: primary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void handleKey(RawKeyEvent event) {
    final isShiftPressed = event.isShiftPressed;
    final isEnterPressed = event.isKeyPressed(LogicalKeyboardKey.enter);
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
      if (!isShiftPressed && isEnterPressed) {
        final text = widget.controller?.text ?? '';
        if (text.trim().isNotEmpty) {
          widget.onSubmitted?.call(text);
        }
        widget.focusNode?.unfocus();
      }
    }
  }

  void handleTap() {
    final text = widget.controller?.text ?? '';
    if (text.trim().isNotEmpty) {
      widget.onSubmitted?.call(text);
    }
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({this.onPressed});

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 32,
      bottom: 80,
      child: FloatingActionButton(
        mini: true,
        shape: CircleBorder(),
        onPressed: onPressed,
        child: Icon(Icons.arrow_downward_outlined, size: 20),
      ),
    );
  }
}
