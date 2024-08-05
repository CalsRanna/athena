import 'package:athena/creator/setting.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/page/mobile/home/widget/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
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
      appBar: AppBar(
        actions: [
          Watcher((context, ref, child) {
            final setting = ref.watch(settingEmitter.asyncData).data;
            if (setting == null) {
              return const SizedBox();
            } else {
              final sun = HugeIcon(
                color: onSurface,
                icon: HugeIcons.strokeRoundedSun02,
              );
              final moon = HugeIcon(
                color: onSurface,
                icon: HugeIcons.strokeRoundedMoon02,
              );
              return IconButton(
                icon: setting.darkMode ? sun : moon,
                onPressed: triggerDarkMode,
              );
            }
          }),
        ],
        centerTitle: true,
        title: const Text('Athena'),
      ),
      body: const ChatWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: handlePressed,
        child: HugeIcon(
          color: onSurface,
          icon: HugeIcons.strokeRoundedAiChat02,
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

  void handlePressed() async {
    final router = GoRouter.of(context);
    await ChatProvider.of(context).create();
    router.push('/chat');
  }
}
