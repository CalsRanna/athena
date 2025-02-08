import 'dart:io';

import 'package:athena/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  List<AutoRoute> get routes {
    var desktopSettingChildren = [
      DesktopRoute(page: DesktopSettingAccountRoute.page),
      DesktopRoute(page: DesktopSettingModelRoute.page),
    ];
    var desktopSettingRoute = DesktopRoute(
      page: DesktopSettingRoute.page,
      children: desktopSettingChildren,
    );
    return [
      DesktopRoute(page: DesktopHomeRoute.page, initial: isDesktop),
      desktopSettingRoute,
      DesktopRoute(page: DesktopSentinelGridRoute.page),
      DesktopRoute(page: DesktopSentinelFormRoute.page),
      AutoRoute(page: MobileHomeRoute.page, initial: !isDesktop),
      AutoRoute(page: MobileChatRoute.page),
      AutoRoute(page: MobileChatListRoute.page),
      AutoRoute(page: MobileChatRenameRoute.page),
      AutoRoute(page: MobileTavernRoute.page),
      AutoRoute(page: MobileStoryRoute.page),
      AutoRoute(page: MobileSentinelListRoute.page),
      AutoRoute(page: MobileSentinelFormRoute.page),
      AutoRoute(page: MobileModelListRoute.page),
      AutoRoute(page: MobileModelFormRoute.page),
    ];
  }
}

class DesktopRoute<R> extends CustomRoute<R> {
  DesktopRoute({super.initial, required super.page, super.children})
      : super(transitionsBuilder: TransitionsBuilders.noTransition);
}
