// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/page/desktop/home/home.dart' as _i1;
import 'package:athena/page/desktop/setting/default_model.dart' as _i3;
import 'package:athena/page/desktop/setting/provider.dart' as _i5;
import 'package:athena/page/desktop/setting/sentinel/form.dart' as _i2;
import 'package:athena/page/desktop/setting/sentinel/sentinel.dart' as _i6;
import 'package:athena/page/desktop/setting/setting.dart' as _i4;
import 'package:athena/page/mobile/chat/chat.dart' as _i8;
import 'package:athena/page/mobile/chat/list.dart' as _i7;
import 'package:athena/page/mobile/default_model.dart/default_model_form_page.dart'
    as _i9;
import 'package:athena/page/mobile/home/home.dart' as _i10;
import 'package:athena/page/mobile/provider/model_form_page.dart' as _i11;
import 'package:athena/page/mobile/provider/provider_form_page.dart' as _i12;
import 'package:athena/page/mobile/provider/provider_list_page.dart' as _i13;
import 'package:athena/page/mobile/provider/provider_name_page.dart' as _i14;
import 'package:athena/page/mobile/sentinel/form.dart' as _i15;
import 'package:athena/page/mobile/sentinel/list.dart' as _i16;
import 'package:athena/schema/chat.dart' as _i20;
import 'package:athena/schema/model.dart' as _i21;
import 'package:athena/schema/provider.dart' as _i22;
import 'package:athena/schema/sentinel.dart' as _i19;
import 'package:auto_route/auto_route.dart' as _i17;
import 'package:flutter/material.dart' as _i18;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i17.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i17.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSentinelFormPage]
class DesktopSentinelFormRoute
    extends _i17.PageRouteInfo<DesktopSentinelFormRouteArgs> {
  DesktopSentinelFormRoute({
    _i18.Key? key,
    _i19.Sentinel? sentinel,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          DesktopSentinelFormRoute.name,
          args: DesktopSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelFormRoute';

  static _i17.PageInfo page = _i17.PageInfo(
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

  final _i18.Key? key;

  final _i19.Sentinel? sentinel;

  @override
  String toString() {
    return 'DesktopSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i3.DesktopSettingDefaultModelPage]
class DesktopSettingDefaultModelRoute extends _i17.PageRouteInfo<void> {
  const DesktopSettingDefaultModelRoute({List<_i17.PageRouteInfo>? children})
      : super(
          DesktopSettingDefaultModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingDefaultModelRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingDefaultModelPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingPage]
class DesktopSettingRoute extends _i17.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i17.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingProviderPage]
class DesktopSettingProviderRoute extends _i17.PageRouteInfo<void> {
  const DesktopSettingProviderRoute({List<_i17.PageRouteInfo>? children})
      : super(
          DesktopSettingProviderRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingProviderRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingProviderPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingSentinelPage]
class DesktopSettingSentinelRoute extends _i17.PageRouteInfo<void> {
  const DesktopSettingSentinelRoute({List<_i17.PageRouteInfo>? children})
      : super(
          DesktopSettingSentinelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingSentinelRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingSentinelPage();
    },
  );
}

/// generated route for
/// [_i7.MobileChatListPage]
class MobileChatListRoute extends _i17.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileChatListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileChatListRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i7.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i8.MobileChatPage]
class MobileChatRoute extends _i17.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i18.Key? key,
    required _i20.Chat chat,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          MobileChatRoute.name,
          args: MobileChatRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>();
      return _i8.MobileChatPage(
        key: args.key,
        chat: args.chat,
      );
    },
  );
}

class MobileChatRouteArgs {
  const MobileChatRouteArgs({
    this.key,
    required this.chat,
  });

  final _i18.Key? key;

  final _i20.Chat chat;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i9.MobileDefaultModelFormPage]
class MobileDefaultModelFormRoute extends _i17.PageRouteInfo<void> {
  const MobileDefaultModelFormRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileDefaultModelFormRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileDefaultModelFormRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i9.MobileDefaultModelFormPage();
    },
  );
}

/// generated route for
/// [_i10.MobileHomePage]
class MobileHomeRoute extends _i17.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i10.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i11.MobileModelFormPage]
class MobileModelFormRoute
    extends _i17.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i18.Key? key,
    _i21.Model? model,
    _i22.Provider? provider,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          MobileModelFormRoute.name,
          args: MobileModelFormRouteArgs(
            key: key,
            model: model,
            provider: provider,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileModelFormRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileModelFormRouteArgs>(
          orElse: () => const MobileModelFormRouteArgs());
      return _i11.MobileModelFormPage(
        key: args.key,
        model: args.model,
        provider: args.provider,
      );
    },
  );
}

class MobileModelFormRouteArgs {
  const MobileModelFormRouteArgs({
    this.key,
    this.model,
    this.provider,
  });

  final _i18.Key? key;

  final _i21.Model? model;

  final _i22.Provider? provider;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model, provider: $provider}';
  }
}

/// generated route for
/// [_i12.MobileProviderFormPage]
class MobileProviderFormRoute
    extends _i17.PageRouteInfo<MobileProviderFormRouteArgs> {
  MobileProviderFormRoute({
    _i18.Key? key,
    required _i22.Provider provider,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          MobileProviderFormRoute.name,
          args: MobileProviderFormRouteArgs(
            key: key,
            provider: provider,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileProviderFormRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileProviderFormRouteArgs>();
      return _i12.MobileProviderFormPage(
        key: args.key,
        provider: args.provider,
      );
    },
  );
}

class MobileProviderFormRouteArgs {
  const MobileProviderFormRouteArgs({
    this.key,
    required this.provider,
  });

  final _i18.Key? key;

  final _i22.Provider provider;

  @override
  String toString() {
    return 'MobileProviderFormRouteArgs{key: $key, provider: $provider}';
  }
}

/// generated route for
/// [_i13.MobileProviderListPage]
class MobileProviderListRoute extends _i17.PageRouteInfo<void> {
  const MobileProviderListRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileProviderListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderListRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i13.MobileProviderListPage();
    },
  );
}

/// generated route for
/// [_i14.MobileProviderNamePage]
class MobileProviderNameRoute extends _i17.PageRouteInfo<void> {
  const MobileProviderNameRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileProviderNameRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderNameRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i14.MobileProviderNamePage();
    },
  );
}

/// generated route for
/// [_i15.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i17.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i18.Key? key,
    _i19.Sentinel? sentinel,
    List<_i17.PageRouteInfo>? children,
  }) : super(
          MobileSentinelFormRoute.name,
          args: MobileSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileSentinelFormRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
          orElse: () => const MobileSentinelFormRouteArgs());
      return _i15.MobileSentinelFormPage(
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

  final _i18.Key? key;

  final _i19.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i16.MobileSentinelListPage]
class MobileSentinelListRoute extends _i17.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i17.PageRouteInfo>? children})
      : super(
          MobileSentinelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileSentinelListRoute';

  static _i17.PageInfo page = _i17.PageInfo(
    name,
    builder: (data) {
      return const _i16.MobileSentinelListPage();
    },
  );
}
