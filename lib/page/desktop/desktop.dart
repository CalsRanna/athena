import 'package:athena/extension/date_time.dart';
import 'package:athena/main.dart';
import 'package:athena/model/liaobots_model.dart';
import 'package:athena/provider/liaobots.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/model.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
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
  late ScrollController scrollController;
  late TextEditingController textEditingController;

  bool get showLogo => chat.messages.isEmpty;

  @override
  void initState() {
    super.initState();
    init();
    getChats();
    updateModels();
  }

  @override
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  void init() async {
    scrollController = ScrollController();
    textEditingController = TextEditingController();
  }

  void getChats() async {
    final chats = await isar.chats.where().sortByUpdatedAtDesc().findAll();
    setState(() {
      this.chats = chats;
    });
  }

  Future<void> updateModels() async {
    var models = await isar.models.where().findAll();
    setState(() {
      this.models = models;
    });
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
        await isar.models.clear();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Container(
                color: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.all(8),
                width: 256,
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: createChat,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withOpacity(0.25),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              height: 48,
                              width: 180,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'New Chat',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.25),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          height: 48,
                          width: 48,
                          child: Icon(
                            Icons.space_dashboard_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemBuilder: (context, index) {
                          return _ChatTile(
                            active: chats[index].id == chat.id,
                            chat: chats[index],
                            onTap: () => selectChat(index),
                          );
                        },
                        itemCount: chats.length,
                        separatorBuilder: (context, index) {
                          return SizedBox(height: 8);
                        },
                      ),
                    ),
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      height: 48,
                      width: 256,
                      child: Text(
                        'Some Information',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(width: 32),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (models.isNotEmpty)
                        _ModelSwitcher(
                          current: 0,
                          models: models,
                          onChange: handleSelect,
                        ),
                      if (models.isNotEmpty) SizedBox(height: 16),
                      Expanded(
                        child: showLogo
                            ? Center(
                                child: Text(
                                  'Athena',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.15),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemBuilder: (context, index) {
                                  final message =
                                      chat.messages.reversed.elementAt(index);
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          message.role == 'user'
                                              ? Icons.person_outline
                                              : Icons.smart_toy_outlined,
                                        ),
                                        SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: MarkdownWidget(
                                            data: message.content ?? '',
                                            shrinkWrap: true,
                                            selectable: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                                itemCount: chat.messages.length,
                                reverse: true,
                              ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.25),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: textEditingController,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Ask me anything',
                                ),
                                onSubmitted: handleSubmitted,
                              ),
                            ),
                            SizedBox(width: 16),
                            Icon(
                              Icons.send,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.25),
                              size: 20,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
          Positioned(
            right: 32,
            bottom: 80,
            child: FloatingActionButton(
              mini: true,
              shape: CircleBorder(),
              onPressed: () {},
              child: Icon(
                Icons.arrow_downward_outlined,
                size: 20,
              ),
            ),
          )
        ],
      ),
    );
  }

  void createChat() {
    setState(() {
      chat = Chat();
    });
  }

  void selectChat(int index) {
    setState(() {
      chat = chats[index].withGrowableMessages();
    });
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

  Future<void> fetchResponse() async {
    setState(() {
      chat.messages.add(Message()..role = 'assistant');
    });
    final logger = Logger();
    try {
      final messages = chat.messages
          .where(
              (message) => message.role != 'error' && message.createdAt != null)
          .toList();
      final limitedMessages = messages.reversed
          .take(8)
          .toList()
          .reversed
          .map((message) => {'role': message.role, 'content': message.content})
          .toList();
      final model = chat.model.value ?? models[0];
      print(model.name);
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
    // final ref = context.ref;
    // final response = await LiaobotsProvider().getAccount();
    // ref.set(accountCreator, LiaobotsAccount.fromJson(response));
  }

  Future<void> storeChat() async {
    try {
      // final ref = context.ref;
      chat.model.value = models[0];
      await isar.writeTxn(() async {
        await isar.chats.put(chat);
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
    chat.model.value = models[index];
    await isar.writeTxn(() async {
      chat.model.value = models[index];
      await isar.chats.put(chat);
      await chat.model.save();
    });
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({this.active = false, required this.chat, this.onTap});

  final bool active;
  final Chat chat;
  final void Function()? onTap;

  String get title => chat.title ?? '';

  String get updatedAt {
    if (chat.messages.isEmpty) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(chat.updatedAt!);
    return dateTime.toHumanReadableString();
  }

  IconData get icon {
    if (chat.model.value?.name == 'GPT-4') return Icons.chat_bubble;
    return Icons.chat_bubble_outline;
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
              Icon(
                icon,
                size: 20,
                color: onPrimary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleMedium?.copyWith(color: onPrimary),
                ),
              ),
              Text(
                updatedAt,
                style: titleSmall?.copyWith(color: onPrimary.withOpacity(0.5)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelSwitcher extends StatefulWidget {
  const _ModelSwitcher(
      {super.key, this.current = 0, required this.models, this.onChange});

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
        offset = controller.value * 142;
      });
    });
    controller.animateTo(widget.current.toDouble());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.models.length * 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      padding: EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            left: offset,
            width: 142,
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
          width: 142,
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
