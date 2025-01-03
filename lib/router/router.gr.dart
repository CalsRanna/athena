// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/page/desktop/home/home.dart' as _i2;
import 'package:athena/page/desktop/sentinel/grid.dart' as _i3;
import 'package:athena/page/desktop/setting/account.dart' as _i4;
import 'package:athena/page/desktop/setting/application.dart' as _i5;
import 'package:athena/page/desktop/setting/experimental.dart' as _i6;
import 'package:athena/page/desktop/setting/model.dart' as _i7;
import 'package:athena/page/desktop/setting/setting.dart' as _i8;
import 'package:athena/page/mobile/chat/chat.dart' as _i1;
import 'package:athena/page/mobile/chat/list.dart' as _i9;
import 'package:athena/page/mobile/home/home.dart' as _i10;
import 'package:athena/schema/chat.dart' as _i13;
import 'package:auto_route/auto_route.dart' as _i11;
import 'package:flutter/material.dart' as _i12;

/// generated route for
/// [_i1.ChatPage]
class ChatRoute extends _i11.PageRouteInfo<ChatRouteArgs> {
  ChatRoute({
    _i12.Key? key,
    _i13.Chat? chat,
    List<_i11.PageRouteInfo>? children,
  }) : super(
          ChatRoute.name,
          args: ChatRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'ChatRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<ChatRouteArgs>(orElse: () => const ChatRouteArgs());
      return _i1.ChatPage(
        key: args.key,
        chat: args.chat,
      );
    },
  );
}

class ChatRouteArgs {
  const ChatRouteArgs({
    this.key,
    this.chat,
  });

  final _i12.Key? key;

  final _i13.Chat? chat;

  @override
  String toString() {
    return 'ChatRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i2.DesktopHomePage]
class DesktopHomeRoute extends _i11.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i2.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i3.DesktopSentinelGridPage]
class DesktopSentinelGridRoute extends _i11.PageRouteInfo<void> {
  const DesktopSentinelGridRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSentinelGridRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelGridRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSentinelGridPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingAccountPage]
class DesktopSettingAccountRoute extends _i11.PageRouteInfo<void> {
  const DesktopSettingAccountRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSettingAccountRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingAccountRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingAccountPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingApplicationPage]
class DesktopSettingApplicationRoute extends _i11.PageRouteInfo<void> {
  const DesktopSettingApplicationRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSettingApplicationRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingApplicationRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingApplicationPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingExperimentalPage]
class DesktopSettingExperimentalRoute extends _i11.PageRouteInfo<void> {
  const DesktopSettingExperimentalRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSettingExperimentalRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingExperimentalRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingExperimentalPage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingModelPage]
class DesktopSettingModelRoute extends _i11.PageRouteInfo<void> {
  const DesktopSettingModelRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSettingModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingModelRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingModelPage();
    },
  );
}

/// generated route for
/// [_i8.DesktopSettingPage]
class DesktopSettingRoute extends _i11.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i11.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i8.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i9.MobileChatListPage]
class MobileChatListRoute extends _i11.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i11.PageRouteInfo>? children})
      : super(
          MobileChatListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileChatListRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i9.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i10.MobileHomePage]
class MobileHomeRoute extends _i11.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i11.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i11.PageInfo page = _i11.PageInfo(
    name,
    builder: (data) {
      return const _i10.MobileHomePage();
    },
  );
}
