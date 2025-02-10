import 'dart:io';

import 'package:athena/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  List<AutoRoute> get routes {
    var desktopSettingProviderChildren = [
      DesktopRoute(page: DesktopSettingProviderDeepSeekRoute.page),
      DesktopRoute(page: DesktopSettingProviderOpenRouterRoute.page),
      DesktopRoute(page: DesktopSettingProviderSiliconFlowRoute.page),
    ];
    var desktopSettingProviderRoute = DesktopRoute(
      children: desktopSettingProviderChildren,
      page: DesktopSettingProviderRoute.page,
    );
    var desktopSettingChildren = [
      DesktopRoute(page: DesktopSettingAccountRoute.page),
      DesktopRoute(page: DesktopSentinelGridRoute.page),
      DesktopRoute(page: DesktopSentinelFormRoute.page),
      desktopSettingProviderRoute,
    ];
    var desktopSettingRoute = DesktopRoute(
      children: desktopSettingChildren,
      page: DesktopSettingRoute.page,
    );
    return [
      DesktopRoute(page: DesktopHomeRoute.page, initial: isDesktop),
      desktopSettingRoute,
      AutoRoute(page: MobileHomeRoute.page, initial: !isDesktop),
      AutoRoute(page: MobileChatRoute.page),
      AutoRoute(page: MobileChatListRoute.page),
      AutoRoute(page: MobileChatRenameRoute.page),
      AutoRoute(page: MobileSentinelListRoute.page),
      AutoRoute(page: MobileSentinelFormRoute.page),
      AutoRoute(page: MobileModelListRoute.page),
      AutoRoute(page: MobileModelFormRoute.page),
    ];
  }
}

class DesktopRoute<R> extends CustomRoute<R> {
  DesktopRoute({super.initial, required super.page, super.children})
      : super(
          transitionsBuilder: TransitionsBuilders.noTransition,
          durationInMilliseconds: 0,
          reverseDurationInMilliseconds: 0,
        );
}
