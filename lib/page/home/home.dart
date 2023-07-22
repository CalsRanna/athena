import 'package:athena/creator/account.dart';
import 'package:athena/creator/model.dart';
import 'package:athena/creator/setting.dart';
import 'package:athena/main.dart';
import 'package:athena/model/liaobots_account.dart';
import 'package:athena/page/home/widget/account.dart';
import 'package:athena/provider/liaobots.dart';
import 'package:athena/schema/model.dart';
import 'package:athena/schema/setting.dart';
import 'package:athena/page/home/widget/chat.dart';
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
  void didChangeDependencies() {
    update();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: selectedIndex == 1
            ? [
                EmitterWatcher<Setting>(
                  emitter: settingEmitter,
                  builder: (context, setting) => IconButton(
                    onPressed: triggerDarkMode,
                    icon: Icon(setting.darkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                  ),
                )
              ]
            : null,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selectedIndex == 0 ? 'Athena' : 'Account'),
            if (loading) const SizedBox(width: 8),
            if (loading) const CircularProgressIndicator.adaptive(),
          ],
        ),
      ),
      body: const [ChatWidget(), AccountWidget()][selectedIndex],
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.question_answer_outlined),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: selectedIndex,
        onDestinationSelected: handleDestinationSelected,
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              onPressed: handlePressed,
              child: const Icon(Icons.chat_bubble_outline),
            )
          : null,
    );
  }

  void update() async {
    final ref = context.ref;
    final account = ref.read(accountCreator);
    final models = ref.read(modelsCreator);
    if (account != null && models.isNotEmpty) return;
    setState(() {
      loading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    try {
      await Future.wait([updateAccount(), updateModels()]);
      setState(() {
        loading = false;
      });
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: scheme.error,
        behavior: SnackBarBehavior.floating,
        content: Text(
          error.toString(),
          style: TextStyle(color: scheme.onError),
        ),
      ));
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> updateAccount() async {
    final ref = context.ref;
    final response = await LiaobotsProvider().getAccount();
    ref.set(accountCreator, LiaobotsAccount.fromJson(response));
  }

  Future<void> updateModels() async {
    final ref = context.ref;
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

        ref.set(modelsCreator, models);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } else {
      ref.set(modelsCreator, models);
    }
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

  void handleDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void handlePressed() {
    context.push('/chat');
  }
}
