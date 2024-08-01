import 'package:athena/creator/setting.dart';
import 'package:athena/main.dart';
import 'package:athena/schema/isar.dart';
import 'package:athena/service/chat_provider.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/page/home/widget/chat.dart';
import 'package:creator/creator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Scaffold(
      appBar: AppBar(
        actions: [
          Watcher((context, ref, child) {
            final setting = ref.watch(settingEmitter.asyncData).data;
            if (setting == null) {
              return const SizedBox();
            } else {
              return IconButton(
                icon: Icon(
                  setting.darkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
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
        child: const Icon(Icons.chat_bubble_outline),
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
