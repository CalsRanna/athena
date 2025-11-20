// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena/entity/provider_entity.dart' as _i30;
import 'package:athena/entity/chat_entity.dart' as _i28;
import 'package:athena/entity/model_entity.dart' as _i29;
import 'package:athena/entity/sentinel_entity.dart' as _i31;
import 'package:athena/entity/summary_entity.dart' as _i32;
import 'package:athena/entity/tool_entity.dart' as _i33;
import 'package:athena/page/desktop/home/home.dart' as _i1;
import 'package:athena/page/desktop/setting/about.dart' as _i2;
import 'package:athena/page/desktop/setting/default_model.dart' as _i3;
import 'package:athena/page/desktop/setting/provider/provider.dart' as _i5;
import 'package:athena/page/desktop/setting/sentinel/sentinel.dart' as _i6;
import 'package:athena/page/desktop/setting/server/server.dart' as _i7;
import 'package:athena/page/desktop/setting/setting.dart' as _i4;
import 'package:athena/page/mobile/about/about_page.dart' as _i8;
import 'package:athena/page/mobile/chat/chat.dart' as _i12;
import 'package:athena/page/mobile/chat/chat_configuration.dart' as _i9;
import 'package:athena/page/mobile/chat/chat_export.dart' as _i10;
import 'package:athena/page/mobile/chat/list.dart' as _i11;
import 'package:athena/page/mobile/default_model.dart/default_model_form_page.dart'
    as _i13;
import 'package:athena/page/mobile/home/home.dart' as _i14;
import 'package:athena/page/mobile/provider/model_form_page.dart' as _i15;
import 'package:athena/page/mobile/provider/provider_form_page.dart' as _i16;
import 'package:athena/page/mobile/provider/provider_list_page.dart' as _i17;
import 'package:athena/page/mobile/provider/provider_name_page.dart' as _i18;
import 'package:athena/page/mobile/sentinel/form.dart' as _i19;
import 'package:athena/page/mobile/sentinel/list.dart' as _i20;
import 'package:athena/page/mobile/summary/summary_detail_page.dart' as _i21;
import 'package:athena/page/mobile/summary/summary_page.dart' as _i22;
import 'package:athena/page/mobile/tool/tool_form_page.dart' as _i23;
import 'package:athena/page/mobile/tool/tool_list_page.dart' as _i24;
import 'package:athena/page/mobile/translation/translation_page.dart' as _i25;
import 'package:auto_route/auto_route.dart' as _i26;
import 'package:flutter/material.dart' as _i27;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i26.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopHomeRoute.name, initialChildren: children);

  static const String name = 'DesktopHomeRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSettingAboutPage]
class DesktopSettingAboutRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingAboutRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingAboutRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingAboutRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.DesktopSettingAboutPage();
    },
  );
}

/// generated route for
/// [_i3.DesktopSettingDefaultModelPage]
class DesktopSettingDefaultModelRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingDefaultModelRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingDefaultModelRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingDefaultModelRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingDefaultModelPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingPage]
class DesktopSettingRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingProviderPage]
class DesktopSettingProviderRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingProviderRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingProviderRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingProviderRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingProviderPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingSentinelPage]
class DesktopSettingSentinelRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingSentinelRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingSentinelRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingSentinelRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingSentinelPage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingServerPage]
class DesktopSettingServerRoute extends _i26.PageRouteInfo<void> {
  const DesktopSettingServerRoute({List<_i26.PageRouteInfo>? children})
    : super(DesktopSettingServerRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingServerRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingServerPage();
    },
  );
}

/// generated route for
/// [_i8.MobileAboutPage]
class MobileAboutRoute extends _i26.PageRouteInfo<void> {
  const MobileAboutRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileAboutRoute.name, initialChildren: children);

  static const String name = 'MobileAboutRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i8.MobileAboutPage();
    },
  );
}

/// generated route for
/// [_i9.MobileChatConfigurationPage]
class MobileChatConfigurationRoute
    extends _i26.PageRouteInfo<MobileChatConfigurationRouteArgs> {
  MobileChatConfigurationRoute({
    _i27.Key? key,
    required _i28.ChatEntity chat,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileChatConfigurationRoute.name,
         args: MobileChatConfigurationRouteArgs(key: key, chat: chat),
         initialChildren: children,
       );

  static const String name = 'MobileChatConfigurationRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatConfigurationRouteArgs>();
      return _i9.MobileChatConfigurationPage(key: args.key, chat: args.chat);
    },
  );
}

class MobileChatConfigurationRouteArgs {
  const MobileChatConfigurationRouteArgs({this.key, required this.chat});

  final _i27.Key? key;

  final _i28.ChatEntity chat;

  @override
  String toString() {
    return 'MobileChatConfigurationRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i10.MobileChatExportPage]
class MobileChatExportRoute
    extends _i26.PageRouteInfo<MobileChatExportRouteArgs> {
  MobileChatExportRoute({
    _i27.Key? key,
    required _i28.ChatEntity chat,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileChatExportRoute.name,
         args: MobileChatExportRouteArgs(key: key, chat: chat),
         initialChildren: children,
       );

  static const String name = 'MobileChatExportRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatExportRouteArgs>();
      return _i10.MobileChatExportPage(key: args.key, chat: args.chat);
    },
  );
}

class MobileChatExportRouteArgs {
  const MobileChatExportRouteArgs({this.key, required this.chat});

  final _i27.Key? key;

  final _i28.ChatEntity chat;

  @override
  String toString() {
    return 'MobileChatExportRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i11.MobileChatListPage]
class MobileChatListRoute extends _i26.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileChatListRoute.name, initialChildren: children);

  static const String name = 'MobileChatListRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i11.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i12.MobileChatPage]
class MobileChatRoute extends _i26.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i27.Key? key,
    required _i28.ChatEntity chat,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileChatRoute.name,
         args: MobileChatRouteArgs(key: key, chat: chat),
         initialChildren: children,
       );

  static const String name = 'MobileChatRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>();
      return _i12.MobileChatPage(key: args.key, chat: args.chat);
    },
  );
}

class MobileChatRouteArgs {
  const MobileChatRouteArgs({this.key, required this.chat});

  final _i27.Key? key;

  final _i28.ChatEntity chat;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i13.MobileDefaultModelFormPage]
class MobileDefaultModelFormRoute extends _i26.PageRouteInfo<void> {
  const MobileDefaultModelFormRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileDefaultModelFormRoute.name, initialChildren: children);

  static const String name = 'MobileDefaultModelFormRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i13.MobileDefaultModelFormPage();
    },
  );
}

/// generated route for
/// [_i14.MobileHomePage]
class MobileHomeRoute extends _i26.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileHomeRoute.name, initialChildren: children);

  static const String name = 'MobileHomeRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i14.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i15.MobileModelFormPage]
class MobileModelFormRoute
    extends _i26.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i27.Key? key,
    _i29.ModelEntity? model,
    _i30.ProviderEntity? provider,
    List<_i26.PageRouteInfo>? children,
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

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileModelFormRouteArgs>(
        orElse: () => const MobileModelFormRouteArgs(),
      );
      return _i15.MobileModelFormPage(
        key: args.key,
        model: args.model,
        provider: args.provider,
      );
    },
  );
}

class MobileModelFormRouteArgs {
  const MobileModelFormRouteArgs({this.key, this.model, this.provider});

  final _i27.Key? key;

  final _i29.ModelEntity? model;

  final _i30.ProviderEntity? provider;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model, provider: $provider}';
  }
}

/// generated route for
/// [_i16.MobileProviderFormPage]
class MobileProviderFormRoute
    extends _i26.PageRouteInfo<MobileProviderFormRouteArgs> {
  MobileProviderFormRoute({
    _i27.Key? key,
    required _i30.ProviderEntity provider,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileProviderFormRoute.name,
         args: MobileProviderFormRouteArgs(key: key, provider: provider),
         initialChildren: children,
       );

  static const String name = 'MobileProviderFormRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileProviderFormRouteArgs>();
      return _i16.MobileProviderFormPage(
        key: args.key,
        provider: args.provider,
      );
    },
  );
}

class MobileProviderFormRouteArgs {
  const MobileProviderFormRouteArgs({this.key, required this.provider});

  final _i27.Key? key;

  final _i30.ProviderEntity provider;

  @override
  String toString() {
    return 'MobileProviderFormRouteArgs{key: $key, provider: $provider}';
  }
}

/// generated route for
/// [_i17.MobileProviderListPage]
class MobileProviderListRoute extends _i26.PageRouteInfo<void> {
  const MobileProviderListRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileProviderListRoute.name, initialChildren: children);

  static const String name = 'MobileProviderListRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i17.MobileProviderListPage();
    },
  );
}

/// generated route for
/// [_i18.MobileProviderNamePage]
class MobileProviderNameRoute extends _i26.PageRouteInfo<void> {
  const MobileProviderNameRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileProviderNameRoute.name, initialChildren: children);

  static const String name = 'MobileProviderNameRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i18.MobileProviderNamePage();
    },
  );
}

/// generated route for
/// [_i19.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i26.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i27.Key? key,
    _i31.SentinelEntity? sentinel,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileSentinelFormRoute.name,
         args: MobileSentinelFormRouteArgs(key: key, sentinel: sentinel),
         initialChildren: children,
       );

  static const String name = 'MobileSentinelFormRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
        orElse: () => const MobileSentinelFormRouteArgs(),
      );
      return _i19.MobileSentinelFormPage(
        key: args.key,
        sentinel: args.sentinel,
      );
    },
  );
}

class MobileSentinelFormRouteArgs {
  const MobileSentinelFormRouteArgs({this.key, this.sentinel});

  final _i27.Key? key;

  final _i31.SentinelEntity? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i20.MobileSentinelListPage]
class MobileSentinelListRoute extends _i26.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileSentinelListRoute.name, initialChildren: children);

  static const String name = 'MobileSentinelListRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i20.MobileSentinelListPage();
    },
  );
}

/// generated route for
/// [_i21.MobileSummaryDetailPage]
class MobileSummaryDetailRoute
    extends _i26.PageRouteInfo<MobileSummaryDetailRouteArgs> {
  MobileSummaryDetailRoute({
    _i27.Key? key,
    required _i32.SummaryEntity summary,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileSummaryDetailRoute.name,
         args: MobileSummaryDetailRouteArgs(key: key, summary: summary),
         initialChildren: children,
       );

  static const String name = 'MobileSummaryDetailRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSummaryDetailRouteArgs>();
      return _i21.MobileSummaryDetailPage(key: args.key, summary: args.summary);
    },
  );
}

class MobileSummaryDetailRouteArgs {
  const MobileSummaryDetailRouteArgs({this.key, required this.summary});

  final _i27.Key? key;

  final _i32.SummaryEntity summary;

  @override
  String toString() {
    return 'MobileSummaryDetailRouteArgs{key: $key, summary: $summary}';
  }
}

/// generated route for
/// [_i22.MobileSummaryPage]
class MobileSummaryRoute extends _i26.PageRouteInfo<void> {
  const MobileSummaryRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileSummaryRoute.name, initialChildren: children);

  static const String name = 'MobileSummaryRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i22.MobileSummaryPage();
    },
  );
}

/// generated route for
/// [_i23.MobileToolFormPage]
class MobileToolFormRoute extends _i26.PageRouteInfo<MobileToolFormRouteArgs> {
  MobileToolFormRoute({
    _i27.Key? key,
    required _i33.ToolEntity tool,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         MobileToolFormRoute.name,
         args: MobileToolFormRouteArgs(key: key, tool: tool),
         initialChildren: children,
       );

  static const String name = 'MobileToolFormRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileToolFormRouteArgs>();
      return _i23.MobileToolFormPage(key: args.key, tool: args.tool);
    },
  );
}

class MobileToolFormRouteArgs {
  const MobileToolFormRouteArgs({this.key, required this.tool});

  final _i27.Key? key;

  final _i33.ToolEntity tool;

  @override
  String toString() {
    return 'MobileToolFormRouteArgs{key: $key, tool: $tool}';
  }
}

/// generated route for
/// [_i24.MobileToolListPage]
class MobileToolListRoute extends _i26.PageRouteInfo<void> {
  const MobileToolListRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileToolListRoute.name, initialChildren: children);

  static const String name = 'MobileToolListRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i24.MobileToolListPage();
    },
  );
}

/// generated route for
/// [_i25.MobileTranslationPage]
class MobileTranslationRoute extends _i26.PageRouteInfo<void> {
  const MobileTranslationRoute({List<_i26.PageRouteInfo>? children})
    : super(MobileTranslationRoute.name, initialChildren: children);

  static const String name = 'MobileTranslationRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i25.MobileTranslationPage();
    },
  );
}
