import 'package:athena/model/shortcut.dart';
import 'package:athena/page/mobile/setting/setting.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/provider/sentinel.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/widget/button.dart';
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
      color: Color(0xffffffff),
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(chat.title),
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
      _Welcome(),
      SizedBox(height: 24),
      _NewChat(),
      _Title('Chat history', onTap: () => navigateChatList(context)),
      SizedBox(height: 52, child: _Recent()),
      _Title('Shortcut'),
      SizedBox(height: 160, child: _ShortcutListView()),
      _Title('Sentinel', onTap: () => navigateSentinelList(context)),
      SizedBox(height: 52, child: _Sentinel()),
    ];
    var body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return AScaffold(body: body);
  }

  void navigateChatList(BuildContext context) {
    MobileChatListRoute().push(context);
  }

  void navigateSentinelList(BuildContext context) {
    MobileSentinelListRoute().push(context);
  }
}

class _NewChat extends ConsumerWidget {
  const _NewChat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
    );
    const shapeDecoration = ShapeDecoration(
      color: Color(0xffffffff),
      shape: StadiumBorder(),
    );
    final mediaQuery = MediaQuery.of(context);
    final button = Container(
      decoration: shapeDecoration,
      margin: EdgeInsets.fromLTRB(16, 0, 16, mediaQuery.padding.bottom),
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
    var provider = defaultSentinelNotifierProvider;
    var sentinel = await ref.read(provider.future);
    if (!context.mounted) return;
    MobileChatRoute(sentinel: sentinel).push(context);
  }
}

class _Recent extends ConsumerWidget {
  const _Recent();

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

class _Sentinel extends ConsumerWidget {
  const _Sentinel();

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
    return ListView.separated(
      itemBuilder: (_, index) => _SentinelTile(sentinels[index]),
      itemCount: sentinels.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }
}

class _SentinelTile extends StatelessWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  Widget build(BuildContext context) {
    const innerDecoration = ShapeDecoration(
      color: Color(0xff161616),
      shape: StadiumBorder(),
    );
    const textStyle = TextStyle(
      color: Colors.white,
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
      const Color(0xFFEAEAEA).withValues(alpha: 0.17),
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
      onTap: () => navigateChatPage(context),
      child: Container(
        decoration: shapeDecoration,
        padding: const EdgeInsets.all(1),
        child: innerContainer,
      ),
    );
  }

  void navigateChatPage(BuildContext context) {
    MobileChatRoute(sentinel: sentinel).push(context);
  }
}

class _ShortcutListView extends StatelessWidget {
  const _ShortcutListView();

  @override
  Widget build(BuildContext context) {
    final icons = [
      HugeIcons.strokeRoundedTranslate,
      HugeIcons.strokeRoundedNaturalFood,
      HugeIcons.strokeRoundedCode,
    ];
    final shortcuts = [
      Shortcut()
        ..name = 'Translate'
        ..description = 'Translate input into selected language',
      Shortcut()
        ..name = 'Food'
        ..description = 'Give you a recipe suggestion of healthy food',
      Shortcut()
        ..name = 'Code'
        ..description =
            'Give you a code suggestion about variables, functions, etc',
    ];
    return ListView.separated(
      itemBuilder: (_, index) =>
          _ShortcutTile(icon: icons[index], shortcut: shortcuts[index]),
      itemCount: shortcuts.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final Shortcut shortcut;

  const _ShortcutTile({required this.icon, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Color(0xFF616161),
      ),
      padding: EdgeInsets.all(12),
      height: 160,
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            shortcut.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              shortcut.description,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
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
      color: Color(0xffffffff),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final body = Row(
      children: [
        Expanded(child: Text(title, style: textStyle)),
        AIconButton(icon: HugeIcons.strokeRoundedArrowRight02, onTap: onTap),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: body,
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    const circleAvatar = CircleAvatar(
      backgroundImage: AssetImage('asset/image/avatar.png'),
      radius: 32,
    );
    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context),
      child: circleAvatar,
    );
    const textStyle = TextStyle(
      color: Color(0xffffffff),
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final children = [
      Expanded(child: Text('Good ${getPeriod()}, Cals', style: textStyle)),
      gestureDetector,
    ];
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: row,
    );
  }

  String getPeriod() {
    final now = DateTime.now();
    if (now.hour < 12) {
      return 'morning';
    } else if (now.hour < 18) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }

  void handleTap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return const SettingPage();
    }));
  }
}
