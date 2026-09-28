import 'package:athena_core/util/platform_util.dart';

import 'package:athena_gui/router/router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

final router = AthenaRouter();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@AutoRouterConfig()
class AthenaRouter extends RootStackRouter {
  var isDesktop = PlatformUtil.isDesktop;

  AthenaRouter({super.navigatorKey});

  @override
  List<AutoRoute> get routes {
    var desktopSettingChildren = [
      DesktopRoute(page: DesktopSettingProviderRoute.page),
      DesktopRoute(page: DesktopSettingDefaultModelRoute.page),
      DesktopRoute(page: DesktopSettingSentinelRoute.page),
      DesktopRoute(page: DesktopSettingSkillRoute.page),
      DesktopRoute(page: DesktopSettingExperienceRoute.page),
      DesktopRoute(page: DesktopSettingAgentRoute.page),
      DesktopRoute(page: DesktopSettingGeneralRoute.page),
      DesktopRoute(page: DesktopSettingAboutRoute.page),
    ];
    // 设置是**非透明**路由：它自己画遮罩与居中面板，浮在应用之上
    // （设置面板后面能看见会话）。
    var desktopSettingRoute = DesktopRoute(
      children: desktopSettingChildren,
      page: DesktopSettingRoute.page,
      opaque: false,
    );
    return [
      DesktopRoute(page: DesktopHomeRoute.page, initial: isDesktop),
      desktopSettingRoute,
      AutoRoute(page: MobileHomeRoute.page, initial: !isDesktop),
      AutoRoute(page: MobileChatRoute.page),
      AutoRoute(page: MobileChatConfigurationRoute.page),
      AutoRoute(page: MobileChatListRoute.page),
      AutoRoute(page: MobileSentinelListRoute.page),
      AutoRoute(page: MobileSentinelFormRoute.page),
      AutoRoute(page: MobileSkillListRoute.page),
      AutoRoute(page: MobileSkillDetailRoute.page),
      AutoRoute(page: MobileSkillFormRoute.page),
      AutoRoute(page: MobileExperienceListRoute.page),
      AutoRoute(page: MobileExperienceDetailRoute.page),
      AutoRoute(page: MobileProviderListRoute.page),
      AutoRoute(page: MobileProviderFormRoute.page),
      AutoRoute(page: MobileProviderNameRoute.page),
      AutoRoute(page: MobileModelFormRoute.page),
      AutoRoute(page: MobileDefaultModelFormRoute.page),
      AutoRoute(page: MobileAboutRoute.page),
      AutoRoute(page: MobileDataRoute.page),
      AutoRoute(page: SettingRoute.page),
      AutoRoute(page: MobileAgentRoute.page),
    ];
  }
}

/// 桌面端路由：与 [AutoRoute] 唯一的区别是取消转场动画（桌面端页面主由设置
/// 面板这类非透明浮层构成，做转场反而像在做无谓的动画）。
///
/// `R` 保留为类型参数是为了配合 `CustomRoute<R>`，但仓库里 10 个调用点全是
/// 无参页面（`DesktopHomeRoute.page` 之类），没有一处能推出 `R`，所以给一个
/// `Object?` 默认值——显式写出 `<Object?>` 不会带来任何信息，只会让路由表变噪。
class DesktopRoute<R extends Object?> extends CustomRoute<R> {
  DesktopRoute({
    super.initial,
    required super.page,
    super.children,
    super.opaque,
  }) : super(
         transitionsBuilder: TransitionsBuilders.noTransition,
         durationInMilliseconds: 0,
         reverseDurationInMilliseconds: 0,
       );
}
