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
      DesktopRoute(page: DesktopSettingProviderRoute.page),
      DesktopRoute(page: DesktopSettingDefaultModelRoute.page),
      DesktopRoute(page: DesktopSettingToolRoute.page),
      DesktopRoute(page: DesktopSettingSentinelRoute.page),
      DesktopRoute(page: DesktopSentinelFormRoute.page),
      DesktopRoute(page: DesktopSettingAboutRoute.page),
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
      AutoRoute(page: MobileChatConfigurationRoute.page),
      AutoRoute(page: MobileChatExportRoute.page),
      AutoRoute(page: MobileChatListRoute.page),
      AutoRoute(page: MobileSentinelListRoute.page),
      AutoRoute(page: MobileSentinelFormRoute.page),
      AutoRoute(page: MobileProviderListRoute.page),
      AutoRoute(page: MobileProviderFormRoute.page),
      AutoRoute(page: MobileProviderNameRoute.page),
      AutoRoute(page: MobileModelFormRoute.page),
      AutoRoute(page: MobileDefaultModelFormRoute.page),
      AutoRoute(page: MobileToolListRoute.page),
      AutoRoute(page: MobileToolFormRoute.page),
      AutoRoute(page: MobileAboutRoute.page),
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
