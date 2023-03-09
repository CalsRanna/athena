import 'package:athena/page/chat.dart';
import 'package:athena/page/home/advanced_setting.dart';
import 'package:athena/page/home/home.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(routes: [
  GoRoute(builder: (_, __) => const HomePage(), path: '/'),
  GoRoute(builder: (_, __) => const ChatPage(), path: '/chat'),
  GoRoute(
    builder: (_, state) => ChatPage(id: int.tryParse(state.params['id'] ?? '')),
    path: '/chat/:id',
  ),
  GoRoute(
    builder: (_, state) => const AdvancedSetting(),
    path: '/setting/advanced',
  ),
]);
