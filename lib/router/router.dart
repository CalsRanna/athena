import 'dart:io';

import 'package:athena/page/desktop/desktop.dart';
import 'package:athena/page/mobile/chat.dart';
import 'package:athena/page/mobile/home/home.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final router = GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
      builder: (_, __) {
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return const Desktop();
        } else {
          return const HomePage();
        }
      },
      path: '/',
    ),
    GoRoute(builder: (_, __) => const ChatPage(), path: '/chat'),
    GoRoute(
      builder: (_, state) {
        return ChatPage(id: int.tryParse(state.pathParameters['id'] ?? ''));
      },
      path: '/chat/:id',
    ),
  ],
);
