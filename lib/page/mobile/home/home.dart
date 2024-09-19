import 'package:athena/creator/setting.dart';
import 'package:athena/provider/chat.dart';
import 'package:athena/schema/chat.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/schema/setting.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff333333),
              Color(0xff111111),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Good evening, Cals',
                        style: TextStyle(
                          color: Color(0xffffffff),
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    CircleAvatar(),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent',
                        style: TextStyle(
                          color: Color(0xffffffff),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: Colors.white),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 52, child: _Recent()),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sentinel',
                        style: TextStyle(
                          color: Color(0xffffffff),
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: Colors.white),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 52, child: _Sentinel()),
                const Spacer(),
                const _NewChat()
              ],
            ),
          ),
        ),
      ),
    );
  }

  void triggerDarkMode() async {
    try {
      final ref = context.ref;
      await isar.writeTxn(() async {
        var setting = await isar.settings.where().findFirst() ?? Setting();
        setting.darkMode = !setting.darkMode;
        isar.settings.put(setting);
        ref.emit(settingEmitter, setting);
      });
    } catch (error) {
      Logger().e(error);
    }
  }
}

class _NewChat extends ConsumerWidget {
  const _NewChat({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatNotifierProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context),
      child: Container(
        decoration: const ShapeDecoration(
          color: Color(0xffffffff),
          shape: StadiumBorder(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: Color(0xff6A5ACD),
            ),
            Text(
              'New Chat',
              style: TextStyle(
                color: Color(0xff6A5ACD),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void handlePressed(BuildContext context) async {
    final router = GoRouter.of(context);
    router.push('/chat');
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
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) => _ChatTile(chats[index]),
      itemCount: chats.length,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return const SizedBox();
  }

  Widget loading() {
    return const SizedBox();
  }
}

class _ChatTile extends ConsumerWidget {
  final Chat chat;
  const _ChatTile(this.chat);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handlePressed(context, ref),
      child: Container(
        decoration: const ShapeDecoration(
          color: Color(0xffffffff),
          shape: StadiumBorder(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(chat.title ?? ''),
      ),
    );
  }

  void handlePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(chatNotifierProvider.notifier);
    await notifier.replace(chat);
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    router.push('/chat/${chat.id}');
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
    if (sentinels.isEmpty) return _SentinelTile(Sentinel()..name = 'Athena');
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) => _SentinelTile(sentinels[index]),
      itemCount: sentinels.length,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
    );
  }

  Widget error(Object error, StackTrace stackTrace) {
    return const SizedBox();
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
    return Container(
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xffffffff).withOpacity(0.2),
            Color(0xff333333),
          ],
          stops: [0, 0.4],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: StadiumBorder(),
      ),
      padding: EdgeInsets.all(1),
      child: Container(
        decoration: ShapeDecoration(
          color: Color(0xff333333),
          shape: const StadiumBorder(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(sentinel.name, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
