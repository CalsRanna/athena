import 'dart:io';

import 'package:athena/page/chat.dart';
import 'package:athena/page/desktop.dart';
import 'package:athena/page/home/home.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(routes: [
  GoRoute(
      builder: (_, __) {
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return const Desktop();
        } else {
          return const HomePage();
        }
      },
      path: '/'),
  GoRoute(builder: (_, __) => const ChatPage(), path: '/chat'),
  GoRoute(
    builder: (_, state) =>
        ChatPage(id: int.tryParse(state.pathParameters['id'] ?? '')),
    path: '/chat/:id',
  ),
]);
