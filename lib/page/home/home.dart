import 'package:athena/page/home/widget/chat.dart';
import 'package:athena/page/home/widget/setting.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  void handleDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void handlePressed() {
    context.push('/chat');
  }
}
