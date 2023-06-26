import 'package:athena/page/advanced.dart';
import 'package:athena/page/chat.dart';
import 'package:athena/page/home/home.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(routes: [
  GoRoute(builder: (_, __) => const HomePage(), path: '/'),
  GoRoute(builder: (_, __) => const ChatPage(), path: '/chat'),
  GoRoute(
    builder: (_, state) =>
        ChatPage(id: int.tryParse(state.pathParameters['id'] ?? '')),
    path: '/chat/:id',
  ),
  GoRoute(
    builder: (_, state) => const AdvancedPage(),
    path: '/setting/advanced',
  ),
]);
