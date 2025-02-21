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
import 'package:athena/page/mobile/chat/rename.dart' as _i9;
import 'package:athena/page/mobile/default_model.dart/default_model_form_page.dart'
    as _i10;
import 'package:athena/page/mobile/home/home.dart' as _i11;
import 'package:athena/page/mobile/provider/provider_form_page.dart' as _i14;
import 'package:athena/page/mobile/provider/provider_list_page.dart' as _i15;
import 'package:athena/page/mobile/provider/provider_name_page.dart' as _i16;
import 'package:athena/page/mobile/sentinel/form.dart' as _i17;
import 'package:athena/page/mobile/sentinel/list.dart' as _i18;
import 'package:athena/page/mobile/setting/model/form.dart' as _i12;
import 'package:athena/page/mobile/setting/model/list.dart' as _i13;
import 'package:athena/schema/chat.dart' as _i22;
import 'package:athena/schema/model.dart' as _i23;
import 'package:athena/schema/provider.dart' as _i24;
import 'package:athena/schema/sentinel.dart' as _i21;
import 'package:auto_route/auto_route.dart' as _i19;
import 'package:flutter/material.dart' as _i20;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i19.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i19.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSentinelFormPage]
class DesktopSentinelFormRoute
    extends _i19.PageRouteInfo<DesktopSentinelFormRouteArgs> {
  DesktopSentinelFormRoute({
    _i20.Key? key,
    _i21.Sentinel? sentinel,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          DesktopSentinelFormRoute.name,
          args: DesktopSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelFormRoute';

  static _i19.PageInfo page = _i19.PageInfo(
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

  final _i20.Key? key;

  final _i21.Sentinel? sentinel;

  @override
  String toString() {
    return 'DesktopSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i3.DesktopSettingDefaultModelPage]
class DesktopSettingDefaultModelRoute extends _i19.PageRouteInfo<void> {
  const DesktopSettingDefaultModelRoute({List<_i19.PageRouteInfo>? children})
      : super(
          DesktopSettingDefaultModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingDefaultModelRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingDefaultModelPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingPage]
class DesktopSettingRoute extends _i19.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i19.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingProviderPage]
class DesktopSettingProviderRoute extends _i19.PageRouteInfo<void> {
  const DesktopSettingProviderRoute({List<_i19.PageRouteInfo>? children})
      : super(
          DesktopSettingProviderRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingProviderRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingProviderPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingSentinelPage]
class DesktopSettingSentinelRoute extends _i19.PageRouteInfo<void> {
  const DesktopSettingSentinelRoute({List<_i19.PageRouteInfo>? children})
      : super(
          DesktopSettingSentinelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingSentinelRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingSentinelPage();
    },
  );
}

/// generated route for
/// [_i7.MobileChatListPage]
class MobileChatListRoute extends _i19.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileChatListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileChatListRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i7.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i8.MobileChatPage]
class MobileChatRoute extends _i19.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i20.Key? key,
    _i22.Chat? chat,
    _i21.Sentinel? sentinel,
    List<_i19.PageRouteInfo>? children,
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

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>(
          orElse: () => const MobileChatRouteArgs());
      return _i8.MobileChatPage(
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

  final _i20.Key? key;

  final _i22.Chat? chat;

  final _i21.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i9.MobileChatRenamePage]
class MobileChatRenameRoute
    extends _i19.PageRouteInfo<MobileChatRenameRouteArgs> {
  MobileChatRenameRoute({
    _i20.Key? key,
    required _i22.Chat chat,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          MobileChatRenameRoute.name,
          args: MobileChatRenameRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatRenameRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRenameRouteArgs>();
      return _i9.MobileChatRenamePage(
        key: args.key,
        chat: args.chat,
      );
    },
  );
}

class MobileChatRenameRouteArgs {
  const MobileChatRenameRouteArgs({
    this.key,
    required this.chat,
  });

  final _i20.Key? key;

  final _i22.Chat chat;

  @override
  String toString() {
    return 'MobileChatRenameRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i10.MobileDefaultModelFormPage]
class MobileDefaultModelFormRoute extends _i19.PageRouteInfo<void> {
  const MobileDefaultModelFormRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileDefaultModelFormRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileDefaultModelFormRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i10.MobileDefaultModelFormPage();
    },
  );
}

/// generated route for
/// [_i11.MobileHomePage]
class MobileHomeRoute extends _i19.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i11.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i12.MobileModelFormPage]
class MobileModelFormRoute
    extends _i19.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i20.Key? key,
    _i23.Model? model,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          MobileModelFormRoute.name,
          args: MobileModelFormRouteArgs(
            key: key,
            model: model,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileModelFormRoute';

  static _i19.PageInfo page = _i19.PageInfo(
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

  final _i20.Key? key;

  final _i23.Model? model;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model}';
  }
}

/// generated route for
/// [_i13.MobileModelListPage]
class MobileModelListRoute extends _i19.PageRouteInfo<void> {
  const MobileModelListRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileModelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileModelListRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i13.MobileModelListPage();
    },
  );
}

/// generated route for
/// [_i14.MobileProviderFormPage]
class MobileProviderFormRoute
    extends _i19.PageRouteInfo<MobileProviderFormRouteArgs> {
  MobileProviderFormRoute({
    _i20.Key? key,
    required _i24.Provider provider,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          MobileProviderFormRoute.name,
          args: MobileProviderFormRouteArgs(
            key: key,
            provider: provider,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileProviderFormRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileProviderFormRouteArgs>();
      return _i14.MobileProviderFormPage(
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

  final _i20.Key? key;

  final _i24.Provider provider;

  @override
  String toString() {
    return 'MobileProviderFormRouteArgs{key: $key, provider: $provider}';
  }
}

/// generated route for
/// [_i15.MobileProviderListPage]
class MobileProviderListRoute extends _i19.PageRouteInfo<void> {
  const MobileProviderListRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileProviderListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderListRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i15.MobileProviderListPage();
    },
  );
}

/// generated route for
/// [_i16.MobileProviderNamePage]
class MobileProviderNameRoute extends _i19.PageRouteInfo<void> {
  const MobileProviderNameRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileProviderNameRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderNameRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i16.MobileProviderNamePage();
    },
  );
}

/// generated route for
/// [_i17.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i19.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i20.Key? key,
    _i21.Sentinel? sentinel,
    List<_i19.PageRouteInfo>? children,
  }) : super(
          MobileSentinelFormRoute.name,
          args: MobileSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileSentinelFormRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
          orElse: () => const MobileSentinelFormRouteArgs());
      return _i17.MobileSentinelFormPage(
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

  final _i20.Key? key;

  final _i21.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i18.MobileSentinelListPage]
class MobileSentinelListRoute extends _i19.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i19.PageRouteInfo>? children})
      : super(
          MobileSentinelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileSentinelListRoute';

  static _i19.PageInfo page = _i19.PageInfo(
    name,
    builder: (data) {
      return const _i18.MobileSentinelListPage();
    },
  );
}
