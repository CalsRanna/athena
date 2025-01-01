// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/page/desktop/home/home.dart' as _i2;
import 'package:athena/page/desktop/setting/account.dart' as _i3;
import 'package:athena/page/desktop/setting/application.dart' as _i4;
import 'package:athena/page/desktop/setting/experimental.dart' as _i5;
import 'package:athena/page/desktop/setting/model.dart' as _i6;
import 'package:athena/page/desktop/setting/setting.dart' as _i7;
import 'package:athena/page/mobile/chat/chat.dart' as _i1;
import 'package:athena/page/mobile/home/home.dart' as _i8;
import 'package:auto_route/auto_route.dart' as _i9;
import 'package:flutter/material.dart' as _i10;

/// generated route for
/// [_i1.ChatPage]
class ChatRoute extends _i9.PageRouteInfo<ChatRouteArgs> {
  ChatRoute({
    _i10.Key? key,
    int? id,
    List<_i9.PageRouteInfo>? children,
  }) : super(
          ChatRoute.name,
          args: ChatRouteArgs(
            key: key,
            id: id,
          ),
          initialChildren: children,
        );

  static const String name = 'ChatRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ChatRouteArgs>(orElse: () => const ChatRouteArgs());
      return _i1.ChatPage(
        key: args.key,
        id: args.id,
      );
    },
  );
}

class ChatRouteArgs {
  const ChatRouteArgs({
    this.key,
    this.id,
  });

  final _i10.Key? key;

  final int? id;

  @override
  String toString() {
    return 'ChatRouteArgs{key: $key, id: $id}';
  }
}

/// generated route for
/// [_i2.DesktopHomePage]
class DesktopHomeRoute extends _i9.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i2.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i3.DesktopSettingAccountPage]
class DesktopSettingAccountRoute extends _i9.PageRouteInfo<void> {
  const DesktopSettingAccountRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopSettingAccountRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingAccountRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingAccountPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingApplicationPage]
class DesktopSettingApplicationRoute extends _i9.PageRouteInfo<void> {
  const DesktopSettingApplicationRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopSettingApplicationRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingApplicationRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingApplicationPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingExperimentalPage]
class DesktopSettingExperimentalRoute extends _i9.PageRouteInfo<void> {
  const DesktopSettingExperimentalRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopSettingExperimentalRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingExperimentalRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingExperimentalPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingModelPage]
class DesktopSettingModelRoute extends _i9.PageRouteInfo<void> {
  const DesktopSettingModelRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopSettingModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingModelRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingModelPage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingPage]
class DesktopSettingRoute extends _i9.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i9.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i8.MobileHomePage]
class MobileHomeRoute extends _i9.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i9.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i8.MobileHomePage();
    },
  );
}
