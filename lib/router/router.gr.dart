// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/page/desktop/home/home.dart' as _i1;
import 'package:athena/page/desktop/setting/about.dart' as _i3;
import 'package:athena/page/desktop/setting/default_model.dart' as _i4;
import 'package:athena/page/desktop/setting/provider.dart' as _i6;
import 'package:athena/page/desktop/setting/sentinel/form.dart' as _i2;
import 'package:athena/page/desktop/setting/sentinel/sentinel.dart' as _i7;
import 'package:athena/page/desktop/setting/setting.dart' as _i5;
import 'package:athena/page/desktop/setting/tool.dart' as _i8;
import 'package:athena/page/mobile/about/about_page.dart' as _i9;
import 'package:athena/page/mobile/chat/chat.dart' as _i13;
import 'package:athena/page/mobile/chat/chat_configuration.dart' as _i10;
import 'package:athena/page/mobile/chat/chat_export.dart' as _i11;
import 'package:athena/page/mobile/chat/list.dart' as _i12;
import 'package:athena/page/mobile/default_model.dart/default_model_form_page.dart'
    as _i14;
import 'package:athena/page/mobile/home/home.dart' as _i15;
import 'package:athena/page/mobile/provider/model_form_page.dart' as _i16;
import 'package:athena/page/mobile/provider/provider_form_page.dart' as _i17;
import 'package:athena/page/mobile/provider/provider_list_page.dart' as _i18;
import 'package:athena/page/mobile/provider/provider_name_page.dart' as _i19;
import 'package:athena/page/mobile/sentinel/form.dart' as _i20;
import 'package:athena/page/mobile/sentinel/list.dart' as _i21;
import 'package:athena/page/mobile/tool/tool_form_page.dart' as _i22;
import 'package:athena/page/mobile/tool/tool_list_page.dart' as _i23;
import 'package:athena/schema/chat.dart' as _i27;
import 'package:athena/schema/model.dart' as _i28;
import 'package:athena/schema/provider.dart' as _i29;
import 'package:athena/schema/sentinel.dart' as _i26;
import 'package:athena/schema/tool.dart' as _i30;
import 'package:auto_route/auto_route.dart' as _i24;
import 'package:flutter/material.dart' as _i25;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i24.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopHomeRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSentinelFormPage]
class DesktopSentinelFormRoute
    extends _i24.PageRouteInfo<DesktopSentinelFormRouteArgs> {
  DesktopSentinelFormRoute({
    _i25.Key? key,
    _i26.Sentinel? sentinel,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          DesktopSentinelFormRoute.name,
          args: DesktopSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'DesktopSentinelFormRoute';

  static _i24.PageInfo page = _i24.PageInfo(
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

  final _i25.Key? key;

  final _i26.Sentinel? sentinel;

  @override
  String toString() {
    return 'DesktopSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i3.DesktopSettingAboutPage]
class DesktopSettingAboutRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingAboutRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingAboutRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingAboutRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingAboutPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingDefaultModelPage]
class DesktopSettingDefaultModelRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingDefaultModelRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingDefaultModelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingDefaultModelRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingDefaultModelPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingPage]
class DesktopSettingRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingProviderPage]
class DesktopSettingProviderRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingProviderRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingProviderRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingProviderRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingProviderPage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingSentinelPage]
class DesktopSettingSentinelRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingSentinelRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingSentinelRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingSentinelRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingSentinelPage();
    },
  );
}

/// generated route for
/// [_i8.DesktopSettingToolPage]
class DesktopSettingToolRoute extends _i24.PageRouteInfo<void> {
  const DesktopSettingToolRoute({List<_i24.PageRouteInfo>? children})
      : super(
          DesktopSettingToolRoute.name,
          initialChildren: children,
        );

  static const String name = 'DesktopSettingToolRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i8.DesktopSettingToolPage();
    },
  );
}

/// generated route for
/// [_i9.MobileAboutPage]
class MobileAboutRoute extends _i24.PageRouteInfo<void> {
  const MobileAboutRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileAboutRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileAboutRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i9.MobileAboutPage();
    },
  );
}

/// generated route for
/// [_i10.MobileChatConfigurationPage]
class MobileChatConfigurationRoute
    extends _i24.PageRouteInfo<MobileChatConfigurationRouteArgs> {
  MobileChatConfigurationRoute({
    _i25.Key? key,
    required _i27.Chat chat,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileChatConfigurationRoute.name,
          args: MobileChatConfigurationRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatConfigurationRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatConfigurationRouteArgs>();
      return _i10.MobileChatConfigurationPage(
        key: args.key,
        chat: args.chat,
      );
    },
  );
}

class MobileChatConfigurationRouteArgs {
  const MobileChatConfigurationRouteArgs({
    this.key,
    required this.chat,
  });

  final _i25.Key? key;

  final _i27.Chat chat;

  @override
  String toString() {
    return 'MobileChatConfigurationRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i11.MobileChatExportPage]
class MobileChatExportRoute
    extends _i24.PageRouteInfo<MobileChatExportRouteArgs> {
  MobileChatExportRoute({
    _i25.Key? key,
    required _i27.Chat chat,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileChatExportRoute.name,
          args: MobileChatExportRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatExportRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatExportRouteArgs>();
      return _i11.MobileChatExportPage(
        key: args.key,
        chat: args.chat,
      );
    },
  );
}

class MobileChatExportRouteArgs {
  const MobileChatExportRouteArgs({
    this.key,
    required this.chat,
  });

  final _i25.Key? key;

  final _i27.Chat chat;

  @override
  String toString() {
    return 'MobileChatExportRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i12.MobileChatListPage]
class MobileChatListRoute extends _i24.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileChatListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileChatListRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i12.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i13.MobileChatPage]
class MobileChatRoute extends _i24.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i25.Key? key,
    required _i27.Chat chat,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileChatRoute.name,
          args: MobileChatRouteArgs(
            key: key,
            chat: chat,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileChatRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>();
      return _i13.MobileChatPage(
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

  final _i25.Key? key;

  final _i27.Chat chat;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i14.MobileDefaultModelFormPage]
class MobileDefaultModelFormRoute extends _i24.PageRouteInfo<void> {
  const MobileDefaultModelFormRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileDefaultModelFormRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileDefaultModelFormRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i14.MobileDefaultModelFormPage();
    },
  );
}

/// generated route for
/// [_i15.MobileHomePage]
class MobileHomeRoute extends _i24.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileHomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileHomeRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i15.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i16.MobileModelFormPage]
class MobileModelFormRoute
    extends _i24.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i25.Key? key,
    _i28.Model? model,
    _i29.Provider? provider,
    List<_i24.PageRouteInfo>? children,
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

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileModelFormRouteArgs>(
          orElse: () => const MobileModelFormRouteArgs());
      return _i16.MobileModelFormPage(
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

  final _i25.Key? key;

  final _i28.Model? model;

  final _i29.Provider? provider;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model, provider: $provider}';
  }
}

/// generated route for
/// [_i17.MobileProviderFormPage]
class MobileProviderFormRoute
    extends _i24.PageRouteInfo<MobileProviderFormRouteArgs> {
  MobileProviderFormRoute({
    _i25.Key? key,
    required _i29.Provider provider,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileProviderFormRoute.name,
          args: MobileProviderFormRouteArgs(
            key: key,
            provider: provider,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileProviderFormRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileProviderFormRouteArgs>();
      return _i17.MobileProviderFormPage(
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

  final _i25.Key? key;

  final _i29.Provider provider;

  @override
  String toString() {
    return 'MobileProviderFormRouteArgs{key: $key, provider: $provider}';
  }
}

/// generated route for
/// [_i18.MobileProviderListPage]
class MobileProviderListRoute extends _i24.PageRouteInfo<void> {
  const MobileProviderListRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileProviderListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderListRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i18.MobileProviderListPage();
    },
  );
}

/// generated route for
/// [_i19.MobileProviderNamePage]
class MobileProviderNameRoute extends _i24.PageRouteInfo<void> {
  const MobileProviderNameRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileProviderNameRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileProviderNameRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i19.MobileProviderNamePage();
    },
  );
}

/// generated route for
/// [_i20.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i24.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i25.Key? key,
    _i26.Sentinel? sentinel,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileSentinelFormRoute.name,
          args: MobileSentinelFormRouteArgs(
            key: key,
            sentinel: sentinel,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileSentinelFormRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
          orElse: () => const MobileSentinelFormRouteArgs());
      return _i20.MobileSentinelFormPage(
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

  final _i25.Key? key;

  final _i26.Sentinel? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i21.MobileSentinelListPage]
class MobileSentinelListRoute extends _i24.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileSentinelListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileSentinelListRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i21.MobileSentinelListPage();
    },
  );
}

/// generated route for
/// [_i22.MobileToolFormPage]
class MobileToolFormRoute extends _i24.PageRouteInfo<MobileToolFormRouteArgs> {
  MobileToolFormRoute({
    _i25.Key? key,
    required _i30.Tool tool,
    List<_i24.PageRouteInfo>? children,
  }) : super(
          MobileToolFormRoute.name,
          args: MobileToolFormRouteArgs(
            key: key,
            tool: tool,
          ),
          initialChildren: children,
        );

  static const String name = 'MobileToolFormRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileToolFormRouteArgs>();
      return _i22.MobileToolFormPage(
        key: args.key,
        tool: args.tool,
      );
    },
  );
}

class MobileToolFormRouteArgs {
  const MobileToolFormRouteArgs({
    this.key,
    required this.tool,
  });

  final _i25.Key? key;

  final _i30.Tool tool;

  @override
  String toString() {
    return 'MobileToolFormRouteArgs{key: $key, tool: $tool}';
  }
}

/// generated route for
/// [_i23.MobileToolListPage]
class MobileToolListRoute extends _i24.PageRouteInfo<void> {
  const MobileToolListRoute({List<_i24.PageRouteInfo>? children})
      : super(
          MobileToolListRoute.name,
          initialChildren: children,
        );

  static const String name = 'MobileToolListRoute';

  static _i24.PageInfo page = _i24.PageInfo(
    name,
    builder: (data) {
      return const _i23.MobileToolListPage();
    },
  );
}
