import 'dart:io';

import 'package:athena/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  var isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  List<AutoRoute> get routes {
    var desktopSettingChildren = [
      AutoRoute(page: DesktopSettingAccountRoute.page),
      AutoRoute(page: DesktopSettingModelRoute.page),
      AutoRoute(page: DesktopSettingApplicationRoute.page),
      AutoRoute(page: DesktopSettingExperimentalRoute.page),
    ];
    var desktopSettingRoute = AutoRoute(
      page: DesktopSettingRoute.page,
      children: desktopSettingChildren,
    );
    return [
      AutoRoute(page: DesktopHomeRoute.page, initial: isDesktop),
      desktopSettingRoute,
      AutoRoute(page: MobileHomeRoute.page, initial: !isDesktop),
      AutoRoute(page: ChatRoute.page),
    ];
  }
}
