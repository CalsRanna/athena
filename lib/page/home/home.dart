import 'package:athena/creator/global.dart';
import 'package:athena/creator/setting.dart';
import 'package:athena/model/setting.dart';
import 'package:athena/page/home/widget/chat.dart';
import 'package:athena/page/home/widget/setting.dart';
import 'package:creator/creator.dart';
import 'package:creator_watcher/creator_watcher.dart';
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
  bool loading = false;
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          EmitterWatcher<Setting>(
            emitter: settingEmitter,
            builder: (context, setting) => IconButton(
              onPressed: triggerDarkMode,
              icon: Icon(setting.darkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
            ),
          )
        ],
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const CircularProgressIndicator.adaptive(),
            if (loading) const SizedBox(width: 8),
            Text(selectedIndex == 0 ? 'Athena' : 'Setting'),
          ],
        ),
      ),
      body: const [ChatWidget(), SettingWidget()][selectedIndex],
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Setting',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: handleDestinationSelected,
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              onPressed: handlePressed,
              child: const Icon(
                Icons.chat_bubble_outline,
              ),
            )
          : null,
    );
  }

  void triggerDarkMode() async {
    try {
      final ref = context.ref;
      final isar = await ref.read(isarEmitter);
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

  void handleDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void handlePressed() {
    context.push('/chat');
  }
}
