import 'package:athena/page/desktop/home/component/chat_indicator.dart';
import 'package:athena/page/desktop/home/component/chat_list.dart';
import 'package:athena/page/desktop/home/component/message_input.dart';
import 'package:athena/page/desktop/home/component/message_list.dart';
import 'package:athena/page/desktop/home/component/sentinel_placeholder.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/model.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/widget/app_bar.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar/isar.dart';

@RoutePage()
class DesktopHomePage extends ConsumerStatefulWidget {
  const DesktopHomePage({super.key});

  @override
  ConsumerState<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends ConsumerState<DesktopHomePage> {
  Chat? chat;
  Model? model;
  Sentinel? sentinel;

  @override
  void initState() {
    super.initState();
    _iniState();
  }

  Future<void> _iniState() async {
    _initModel();
    _initSentinel();
  }

  Future<void> _initModel() async {
    var provider = groupedEnabledModelsNotifierProvider;
    var result = await ref.read(provider.future);
    if (result.isEmpty) return;
    var entry = result.entries.first;
    var models = entry.value;
    if (models.isEmpty) return;
    setState(() {
      model = models.first;
    });
    print(model);
  }

  Future<void> _initSentinel() async {
    var provider = sentinelsNotifierProvider;
    var sentinels = await ref.read(provider.future);
    if (sentinels.isEmpty) return;
    setState(() {
      sentinel = sentinels.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    var children = [_buildLeftBar(), Expanded(child: _buildRightWorkspace())];
    return AScaffold(appBar: _buildAppBar(), body: Row(children: children));
  }

  Future<void> changeChat(Chat chat) async {
    var model = await isar.models.filter().idEqualTo(chat.modelId).findFirst();
    var sentinel =
        await isar.sentinels.filter().idEqualTo(chat.sentinelId).findFirst();
    setState(() {
      this.chat = chat;
      this.model = model;
      this.sentinel = sentinel;
    });
  }

  void changeModel(Model model) {
    setState(() {
      this.model = model;
    });
    if (chat == null) return;
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat!.id);
    var notifier = container.read(provider.notifier);
    notifier.updateModel(model);
  }

  void changeSentinel(Sentinel sentinel) {
    setState(() {
      this.sentinel = sentinel;
    });
    if (chat == null) return;
    var container = ProviderScope.containerOf(context);
    var provider = chatNotifierProvider(chat!.id);
    var notifier = container.read(provider.notifier);
    notifier.updateSentinel(sentinel);
  }

  void createChat() {
    setState(() {
      chat = null;
      model = null;
      sentinel = null;
    });
  }

  void destroyChat() {
    setState(() {
      chat = null;
      model = null;
      sentinel = null;
    });
  }

  void navigateSetting(BuildContext context) {
    DesktopSettingAccountRoute().push(context);
  }

  Future<void> submit(String text) async {
    if (chat == null) {
      var container = ProviderScope.containerOf(context);
      var provider = chatNotifierProvider(chat?.id ?? 0);
      var notifier = container.read(provider.notifier);
      var chatId = await notifier.create(model: model, sentinel: sentinel);
      setState(() {
        chat = Chat()..id = chatId;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var container = ProviderScope.containerOf(context);
      var provider = chatNotifierProvider(chat!.id);
      var notifier = container.read(provider.notifier);
      notifier.send(text, model: model!, sentinel: sentinel!);
    });
  }

  Widget _buildAppBar() {
    var icon = Icon(
      HugeIcons.strokeRoundedPencilEdit02,
      color: Colors.white,
      size: 24,
    );
    var chatCreateButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: createChat,
      child: icon,
    );
    return AAppBar(
      action: _buildSettingButton(),
      leading: Align(alignment: Alignment.centerRight, child: chatCreateButton),
      title: DesktopChatIndicator(model: model, sentinel: sentinel),
    );
  }

  Widget _buildLeftBar() {
    var chatListView = DesktopChatListView(
      onDestroyed: destroyChat,
      onSelected: changeChat,
      selectedChat: chat,
    );
    var borderSide = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    var boxDecoration = BoxDecoration(border: Border(right: borderSide));
    return Container(
      decoration: boxDecoration,
      height: double.infinity,
      width: 200,
      child: chatListView,
    );
  }

  Widget _buildRightWorkspace() {
    var stackChildren = [
      if (chat == null) DesktopSentinelPlaceholder(sentinel: sentinel),
      if (model != null && sentinel != null)
        DesktopMessageList(chat: chat, model: model!, sentinel: sentinel!),
    ];
    var children = [
      Expanded(child: Stack(children: stackChildren)),
      DesktopMessageInput(onModelChanged: changeModel, onSubmitted: submit)
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildSettingButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateSetting(context),
      child: const Icon(HugeIcons.strokeRoundedSettings01, color: Colors.white),
    );
  }
}
