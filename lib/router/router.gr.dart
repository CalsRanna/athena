// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/page/desktop/home/home.dart' as _i1;
import 'package:athena/page/desktop/sentinel/form.dart' as _i2;
import 'package:athena/page/desktop/sentinel/grid.dart' as _i3;
import 'package:athena/page/desktop/setting/account.dart' as _i4;
import 'package:athena/page/desktop/setting/application.dart' as _i5;
import 'package:athena/page/desktop/setting/experimental.dart' as _i6;
import 'package:athena/page/desktop/setting/model.dart' as _i7;
import 'package:athena/page/desktop/setting/setting.dart' as _i8;
import 'package:athena/page/mobile/chat/chat.dart' as _i10;
import 'package:athena/page/mobile/chat/list.dart' as _i9;
import 'package:athena/page/mobile/home/home.dart' as _i11;
import 'package:athena/page/mobile/sentinel/form.dart' as _i14;
import 'package:athena/page/mobile/sentinel/list.dart' as _i15;
import 'package:athena/page/mobile/setting/model/form.dart' as _i12;
import 'package:athena/page/mobile/setting/model/list.dart' as _i13;
import 'package:athena/schema/chat.dart' as _i18;
import 'package:athena/schema/model.dart' as _i19;
import 'package:auto_route/auto_route.dart' as _i16;
import 'package:flutter/material.dart' as _i17;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i16.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSentinelFormPage]
class DesktopSentinelFormRoute
    extends _i16.PageRouteInfo<DesktopSentinelFormRouteArgs> {
  DesktopSentinelFormRoute({
    _i17.Key? key,
    _i18.Sentinel? sentinel,
    List<_i16.PageRouteInfo>? children,
  }) : super(
          DesktopSentinelFormRoute.name,
          args: DesktopSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelFormRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DesktopSentinelFormRouteArgs>(
          orElse: () => const DesktopSentinelFormRouteArgs());
      return _i2.DesktopSentinelFormPage(
        key: args.key,
        sentinel: args.sentinel,
      );
    },
  );
}

class DesktopSentinelFormRouteArgs {
  const DesktopSentinelFormRouteArgs({
    this.key,
    this.sentinel,
  });

  final _i17.Key? key;

  final _i18.Sentinel? sentinel;

  @override
  String toString() {
    return 'DesktopSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i3.DesktopSentinelGridPage]
class DesktopSentinelGridRoute extends _i16.PageRouteInfo<void> {
  const DesktopSentinelGridRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSentinelGridRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelGridRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSentinelGridPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingAccountPage]
class DesktopSettingAccountRoute extends _i16.PageRouteInfo<void> {
  const DesktopSettingAccountRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSettingAccountRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingAccountRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingAccountPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingApplicationPage]
class DesktopSettingApplicationRoute extends _i16.PageRouteInfo<void> {
  const DesktopSettingApplicationRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSettingApplicationRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingApplicationRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingApplicationPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingExperimentalPage]
class DesktopSettingExperimentalRoute extends _i16.PageRouteInfo<void> {
  const DesktopSettingExperimentalRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSettingExperimentalRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingExperimentalRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingExperimentalPage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingModelPage]
class DesktopSettingModelRoute extends _i16.PageRouteInfo<void> {
  const DesktopSettingModelRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSettingModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingModelRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingModelPage();
    },
  );
}

/// generated route for
/// [_i8.DesktopSettingPage]
class DesktopSettingRoute extends _i16.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i16.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i8.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i9.MobileChatListPage]
class MobileChatListRoute extends _i16.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i16.PageRouteInfo>? children})
      : super(
          MobileChatListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileChatListRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i9.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i10.MobileChatPage]
class MobileChatRoute extends _i16.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i17.Key? key,
    _i18.Chat? chat,
    _i18.Sentinel? sentinel,
    List<_i16.PageRouteInfo>? children,
  }) : super(
          MobileChatRoute.name,
          args: MobileChatRouteArgs(
            key: key,
            chat: chat,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>(
          orElse: () => const MobileChatRouteArgs());
      return _i10.MobileChatPage(
        key: args.key,
        chat: args.chat,
        sentinel: args.sentinel,
      );
    },
  );
}

class MobileChatRouteArgs {
  const MobileChatRouteArgs({
    this.key,
    this.chat,
    this.sentinel,
  });

  final _i17.Key? key;

  final _i18.Chat? chat;

  final _i18.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i11.MobileHomePage]
class MobileHomeRoute extends _i16.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i16.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i11.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i12.MobileModelFormPage]
class MobileModelFormRoute
    extends _i16.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i17.Key? key,
    _i19.Model? model,
    List<_i16.PageRouteInfo>? children,
  }) : super(
          MobileModelFormRoute.name,
          args: MobileModelFormRouteArgs(
            key: key,
            model: model,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileModelFormRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileModelFormRouteArgs>(
          orElse: () => const MobileModelFormRouteArgs());
      return _i12.MobileModelFormPage(
        key: args.key,
        model: args.model,
      );
    },
  );
}

class MobileModelFormRouteArgs {
  const MobileModelFormRouteArgs({
    this.key,
    this.model,
  });

  final _i17.Key? key;

  final _i19.Model? model;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model}';
  }
}

/// generated route for
/// [_i13.MobileModelListPage]
class MobileModelListRoute extends _i16.PageRouteInfo<void> {
  const MobileModelListRoute({List<_i16.PageRouteInfo>? children})
      : super(
          MobileModelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileModelListRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i13.MobileModelListPage();
    },
  );
}

/// generated route for
/// [_i14.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i16.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i17.Key? key,
    _i18.Sentinel? sentinel,
    List<_i16.PageRouteInfo>? children,
  }) : super(
          MobileSentinelFormRoute.name,
          args: MobileSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileSentinelFormRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
          orElse: () => const MobileSentinelFormRouteArgs());
      return _i14.MobileSentinelFormPage(
        key: args.key,
        sentinel: args.sentinel,
      );
    },
  );
}

class MobileSentinelFormRouteArgs {
  const MobileSentinelFormRouteArgs({
    this.key,
    this.sentinel,
  });

  final _i17.Key? key;

  final _i18.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i15.MobileSentinelListPage]
class MobileSentinelListRoute extends _i16.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i16.PageRouteInfo>? children})
      : super(
          MobileSentinelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileSentinelListRoute';

  static _i16.PageInfo page = _i16.PageInfo(
    name,
    builder: (data) {
      return const _i15.MobileSentinelListPage();
    },
  );
}
