import 'package:athena/model/shortcut.dart';
import 'package:athena/page/mobile/home/component/welcome.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/sentinel.dart';
import 'package:athena/util/color_util.dart';
import 'package:athena/view_model/chat.dart';
import 'package:athena/widget/scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

@RoutePage()
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  const _ChatTile(this.chat);

  @override
  Widget build(BuildContext context) {
    const shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(chat.title.isNotEmpty ? chat.title : '新的对话'),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context),
      child: body,
    );
  }

  void handlePressed(BuildContext context) async {
    MobileChatRoute(chat: chat).push(context);
  }
}

class _MobileHomePageState extends State<MobileHomePage> {
  @override
  Widget build(BuildContext context) {
    var children = [
      MobileHomeWelcome(),
      SizedBox(height: 16),
      _NewChatButton(),
      SizedBox(height: 16),
      _Title('Chat history', onTap: () => navigateChatList(context)),
      SizedBox(height: 8),
      SizedBox(height: 52, child: _RecentChatListView()),
      SizedBox(height: 24),
      _Title('Shortcut'),
      SizedBox(height: 8),
      SizedBox(height: 160, child: _ShortcutListView()),
      SizedBox(height: 24),
      _Title('Sentinel', onTap: () => navigateSentinelList(context)),
      SizedBox(height: 8),
      SizedBox(height: 156, child: _SentinelListView()),
    ];
    var body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AthenaScaffold(body: body);
  }

  void navigateChatList(BuildContext context) {
    MobileChatListRoute().push(context);
  }

  void navigateSentinelList(BuildContext context) {
    MobileSentinelListRoute().push(context);
  }
}

class _NewChatButton extends ConsumerWidget {
  const _NewChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    var boxShadow = BoxShadow(
      blurRadius: 16,
      color: ColorUtil.FFCED2C7.withValues(alpha: 0.5),
    );
    var shapeDecoration = ShapeDecoration(
      color: ColorUtil.FFFFFFFF,
      shadows: [boxShadow],
      shape: StadiumBorder(),
    );
    final button = Container(
      decoration: shapeDecoration,
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Center(child: Text('New Chat', style: textStyle)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: button,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) async {
    var viewModel = ChatViewModel(ref);
    var chat = await viewModel.createChat();
    if (!context.mounted) return;
    MobileChatRoute(chat: chat).push(context);
  }
}

class _RecentChatListView extends ConsumerWidget {
  const _RecentChatListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recentChatsNotifierProvider);
    return state.when(data: data, error: error, loading: loading);
  }

  Widget data(List<Chat> chats) {
    if (chats.isEmpty) return const SizedBox();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => itemBuilder(chats, index),
      itemCount: chats.length,
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return const SizedBox();
  }

  Widget itemBuilder(List<Chat> chats, int index) {
    const left = 16.0;
    final right = index == chats.length - 1 ? 16.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: left, right: right),
      child: _ChatTile(chats[index]),
    );
  }

  Widget loading() {
    return const SizedBox();
  }
}

class _SentinelListView extends ConsumerWidget {
  const _SentinelListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sentinelsNotifierProvider;
    final state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<Sentinel> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    List<Widget> children1 = [];
    List<Widget> children2 = [];
    List<Widget> children3 = [];
    for (var i = 0; i < sentinels.length; i++) {
      var tile = _SentinelTile(sentinels[i]);
      if (i % 3 == 0) children1.add(tile);
      if (i % 3 == 1) children2.add(tile);
      if (i % 3 == 2) children3.add(tile);
    }
    var column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(spacing: 12, children: children1),
        Row(spacing: 12, children: children2),
        Row(spacing: 12, children: children3),
      ],
    );
    return SizedBox(
      height: 120,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        child: column,
      ),
    );
  }
}

class _SentinelTile extends ConsumerWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const innerDecoration = ShapeDecoration(
      color: ColorUtil.FF161616,
      shape: StadiumBorder(),
    );
    const textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final innerContainer = Container(
      alignment: Alignment.center,
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
      child: Text(sentinel.name, style: textStyle),
    );
    final colors = [
      ColorUtil.FFEAEAEA.withValues(alpha: 0.17),
      Colors.transparent,
    ];
    final linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigateChatPage(context, ref),
      child: Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(1),
        child: innerContainer,
      ),
    );
  }

  void navigateChatPage(BuildContext context, WidgetRef ref) async {
    var viewModel = ChatViewModel(ref);
    var chat = await viewModel.createChat(sentinel: sentinel);
    if (!context.mounted) return;
    MobileChatRoute(chat: chat).push(context);
  }
}

class _ShortcutListView extends StatelessWidget {
  const _ShortcutListView();

  @override
  Widget build(BuildContext context) {
    final icons = [
      HugeIcons.strokeRoundedTranslate,
      HugeIcons.strokeRoundedAiBrowser,
      HugeIcons.strokeRoundedCookBook,
      HugeIcons.strokeRoundedCode,
    ];
    final shortcuts = [
      Shortcut()
        ..name = 'Translation'
        ..description = 'Translate input into selected language',
      Shortcut()
        ..name = 'Summary'
        ..description = 'Summary the content in the internet link',
      Shortcut()
        ..name = 'Food'
        ..description = 'Give you a recipe suggestion of healthy food',
      Shortcut()
        ..name = 'Code'
        ..description =
            'Give you a code suggestion about variables, functions, etc',
    ];
    return ListView.separated(
      itemBuilder: (_, index) => _ShortcutTile(
        icon: icons[index],
        onTap: () => navigate(context, shortcuts[index]),
        shortcut: shortcuts[index],
      ),
      itemCount: shortcuts.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }

  void navigate(BuildContext context, Shortcut shortcut) {
    PageRouteInfo? route = switch (shortcut.name) {
      'Translation' => MobileTranslationRoute(),
      'Summary' => MobileSummaryRoute(),
      _ => null,
    };
    if (route != null) route.push(context);
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;
  final Shortcut shortcut;

  const _ShortcutTile({required this.icon, this.onTap, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: ColorUtil.FF616161,
        ),
        padding: EdgeInsets.all(12),
        height: 160,
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ColorUtil.FFFFFFFF),
            const SizedBox(height: 4),
            Text(
              shortcut.name,
              style: const TextStyle(
                color: ColorUtil.FFFFFFFF,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                shortcut.description,
                style: const TextStyle(
                  color: ColorUtil.FFE0E0E0,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  const _Title(this.title, {this.onTap});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: ColorUtil.FFFFFFFF,
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    var children = [
      Expanded(child: Text(title, style: textStyle)),
      _buildMoreButton(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: children),
    );
  }

  Widget _buildMoreButton() {
    var container = Container(
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: ColorUtil.FFFFFFFF),
      padding: EdgeInsets.all(12),
      child: Icon(HugeIcons.strokeRoundedArrowRight02, size: 16),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: container,
    );
  }
}
