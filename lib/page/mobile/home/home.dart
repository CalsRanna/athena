import 'package:athena/page/mobile/setting/setting.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/router/router.gr.dart';
import 'package:athena/schema/chat.dart';
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

class _ChatTile extends ConsumerWidget {
  final Chat chat;
  const _ChatTile(this.chat);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const shapeDecoration = ShapeDecoration(
      color: Color(0xffffffff),
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(chat.title ?? ''),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context, ref),
      child: body,
    );
  }

  void handlePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(chatNotifierProvider.notifier);
    await notifier.replace(chat);
    if (!context.mounted) return;
    ChatRoute(id: chat.id).push(context);
  }
}

class _MobileHomePageState extends State<MobileHomePage> {
  @override
  Widget build(BuildContext context) {
    const children = [
      _Welcome(),
      _Title('Recent'),
      SizedBox(height: 52, child: _Recent()),
      _Title('Shortcut', icon: HugeIcons.strokeRoundedArrowRight02),
      SizedBox(height: 52, child: _Sentinel()),
      _Title('Sentinel', icon: HugeIcons.strokeRoundedArrowRight02),
      SizedBox(height: 52, child: _Sentinel()),
      Spacer(),
      _NewChat()
    ];
    const body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return const AScaffold(body: body);
  }
}

class _NewChat extends ConsumerWidget {
  const _NewChat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatNotifierProvider);
    const textStyle = TextStyle(
      color: Color(0xff6A5ACD),
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    const hugeIcon = HugeIcon(
      icon: HugeIcons.strokeRoundedAdd01,
      color: Color(0xff6A5ACD),
    );
    const row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [hugeIcon, Text('New Chat', style: textStyle)],
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
      child: row,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTap(context, ref),
      child: button,
    );
  }

  void handleTap(BuildContext context, WidgetRef ref) async {
    ref.invalidate(chatNotifierProvider);
    ChatRoute().push(context);
    // final router = GoRouter.of(context);
    // router.push('/chat');
  }
}

class _Recent extends ConsumerWidget {
  const _Recent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatsNotifierProvider);
    return state.when(data: data, error: error, loading: loading);
  }

  Widget data(List<Chat> chats) {
    if (chats.isEmpty) return const SizedBox();
    final reversedChats = chats.reversed.toList();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => itemBuilder(reversedChats, index),
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
    final state = ref.watch(sentinelsNotifierProvider);
    return state.when(data: data, error: error, loading: loading);
  }

  Widget data(List<Sentinel> sentinels) {
    if (sentinels.isEmpty) return const SizedBox();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (_, index) => itemBuilder(sentinels, index),
      itemCount: sentinels.length,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return const SizedBox();
  }

  Widget itemBuilder(List<Sentinel> sentinels, int index) {
    const left = 16.0;
    final right = index == sentinels.length - 1 ? 16.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: left, right: right),
      child: _SentinelTile(sentinels[index]),
    );
  }

  Widget loading() {
    return const SizedBox();
  }
}

class _SentinelTile extends StatelessWidget {
  final Sentinel sentinel;
  const _SentinelTile(this.sentinel);

  @override
  Widget build(BuildContext context) {
    const innerDecoration = ShapeDecoration(
      color: Color(0xff333333),
      shape: StadiumBorder(),
    );
    final body = Container(
      decoration: innerDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(sentinel.name, style: const TextStyle(color: Colors.white)),
    );
    final colors = [
      const Color(0xffffffff).withOpacity(0.2),
      const Color(0xff333333),
    ];
    final linearGradient = LinearGradient(
      begin: Alignment.topLeft,
      colors: colors,
      end: Alignment.bottomRight,
      stops: const [0, 0.4],
    );
    final shapeDecoration = ShapeDecoration(
      gradient: linearGradient,
      shape: const StadiumBorder(),
    );
    return Container(
      decoration: shapeDecoration,
      padding: const EdgeInsets.all(1),
      child: body,
    );
  }
}

class _Title extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Title(this.title, {this.icon = HugeIcons.strokeRoundedSearch01});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xffffffff),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final hugeIcon = HugeIcon(icon: icon, color: Colors.white);
    final body = Row(
      children: [Expanded(child: Text(title, style: textStyle)), hugeIcon],
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
