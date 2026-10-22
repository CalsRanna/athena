// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:athena_core/agent/skill/skill_loader.dart' as _i37;
import 'package:athena_core/entity/chat_entity.dart' as _i32;
import 'package:athena_core/entity/experience_entity.dart' as _i34;
import 'package:athena_core/entity/model_entity.dart' as _i35;
import 'package:athena_core/entity/provider_entity.dart' as _i36;
import 'package:athena_core/entity/sentinel_entity.dart' as _i33;
import 'package:athena_gui/page/desktop/home/home_page.dart' as _i1;
import 'package:athena_gui/page/desktop/setting/about_page.dart' as _i2;
import 'package:athena_gui/page/desktop/setting/agent_page.dart' as _i3;
import 'package:athena_gui/page/desktop/setting/appearance_page.dart' as _i4;
import 'package:athena_gui/page/desktop/setting/data_page.dart' as _i5;
import 'package:athena_gui/page/desktop/setting/experience/experience_page.dart'
    as _i6;
import 'package:athena_gui/page/desktop/setting/provider/provider_page.dart'
    as _i8;
import 'package:athena_gui/page/desktop/setting/sentinel/sentinel_page.dart'
    as _i9;
import 'package:athena_gui/page/desktop/setting/setting_page.dart' as _i7;
import 'package:athena_gui/page/desktop/setting/skill/skill_page.dart' as _i10;
import 'package:athena_gui/page/mobile/about/about_page.dart' as _i11;
import 'package:athena_gui/page/mobile/chat/chat_configuration_page.dart'
    as _i13;
import 'package:athena_gui/page/mobile/chat/chat_list_page.dart' as _i14;
import 'package:athena_gui/page/mobile/chat/chat_page.dart' as _i15;
import 'package:athena_gui/page/mobile/experience/experience_detail_page.dart'
    as _i17;
import 'package:athena_gui/page/mobile/experience/experience_list_page.dart'
    as _i18;
import 'package:athena_gui/page/mobile/home/home_page.dart' as _i19;
import 'package:athena_gui/page/mobile/provider/model_form_page.dart' as _i20;
import 'package:athena_gui/page/mobile/provider/provider_form_page.dart'
    as _i21;
import 'package:athena_gui/page/mobile/provider/provider_list_page.dart'
    as _i22;
import 'package:athena_gui/page/mobile/provider/provider_name_page.dart'
    as _i23;
import 'package:athena_gui/page/mobile/sentinel/sentinel_form_page.dart'
    as _i24;
import 'package:athena_gui/page/mobile/sentinel/sentinel_list_page.dart'
    as _i25;
import 'package:athena_gui/page/mobile/setting/agent_page.dart' as _i12;
import 'package:athena_gui/page/mobile/setting/data_page.dart' as _i16;
import 'package:athena_gui/page/mobile/setting/setting_page.dart' as _i26;
import 'package:athena_gui/page/mobile/skill/skill_detail_page.dart' as _i27;
import 'package:athena_gui/page/mobile/skill/skill_form_page.dart' as _i28;
import 'package:athena_gui/page/mobile/skill/skill_list_page.dart' as _i29;
import 'package:auto_route/auto_route.dart' as _i30;
import 'package:flutter/material.dart' as _i31;

/// generated route for
/// [_i1.DesktopHomePage]
class DesktopHomeRoute extends _i30.PageRouteInfo<void> {
  const DesktopHomeRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopHomeRoute.name, initialChildren: children);

  static const String name = 'DesktopHomeRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i1.DesktopHomePage();
    },
  );
}

/// generated route for
/// [_i2.DesktopSettingAboutPage]
class DesktopSettingAboutRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingAboutRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingAboutRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingAboutRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i2.DesktopSettingAboutPage();
    },
  );
}

/// generated route for
/// [_i3.DesktopSettingAgentPage]
class DesktopSettingAgentRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingAgentRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingAgentRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingAgentRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i3.DesktopSettingAgentPage();
    },
  );
}

/// generated route for
/// [_i4.DesktopSettingAppearancePage]
class DesktopSettingAppearanceRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingAppearanceRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingAppearanceRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingAppearanceRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i4.DesktopSettingAppearancePage();
    },
  );
}

/// generated route for
/// [_i5.DesktopSettingDataPage]
class DesktopSettingDataRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingDataRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingDataRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingDataRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i5.DesktopSettingDataPage();
    },
  );
}

/// generated route for
/// [_i6.DesktopSettingExperiencePage]
class DesktopSettingExperienceRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingExperienceRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingExperienceRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingExperienceRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i6.DesktopSettingExperiencePage();
    },
  );
}

/// generated route for
/// [_i7.DesktopSettingPage]
class DesktopSettingRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i7.DesktopSettingPage();
    },
  );
}

/// generated route for
/// [_i8.DesktopSettingProviderPage]
class DesktopSettingProviderRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingProviderRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingProviderRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingProviderRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i8.DesktopSettingProviderPage();
    },
  );
}

/// generated route for
/// [_i9.DesktopSettingSentinelPage]
class DesktopSettingSentinelRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingSentinelRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingSentinelRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingSentinelRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i9.DesktopSettingSentinelPage();
    },
  );
}

/// generated route for
/// [_i10.DesktopSettingSkillPage]
class DesktopSettingSkillRoute extends _i30.PageRouteInfo<void> {
  const DesktopSettingSkillRoute({List<_i30.PageRouteInfo>? children})
    : super(DesktopSettingSkillRoute.name, initialChildren: children);

  static const String name = 'DesktopSettingSkillRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i10.DesktopSettingSkillPage();
    },
  );
}

/// generated route for
/// [_i11.MobileAboutPage]
class MobileAboutRoute extends _i30.PageRouteInfo<void> {
  const MobileAboutRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileAboutRoute.name, initialChildren: children);

  static const String name = 'MobileAboutRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i11.MobileAboutPage();
    },
  );
}

/// generated route for
/// [_i12.MobileAgentPage]
class MobileAgentRoute extends _i30.PageRouteInfo<void> {
  const MobileAgentRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileAgentRoute.name, initialChildren: children);

  static const String name = 'MobileAgentRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i12.MobileAgentPage();
    },
  );
}

/// generated route for
/// [_i13.MobileChatConfigurationPage]
class MobileChatConfigurationRoute
    extends _i30.PageRouteInfo<MobileChatConfigurationRouteArgs> {
  MobileChatConfigurationRoute({
    _i31.Key? key,
    required _i32.ChatEntity chat,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileChatConfigurationRoute.name,
         args: MobileChatConfigurationRouteArgs(key: key, chat: chat),
         initialChildren: children,
       );

  static const String name = 'MobileChatConfigurationRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatConfigurationRouteArgs>();
      return _i13.MobileChatConfigurationPage(key: args.key, chat: args.chat);
    },
  );
}

class MobileChatConfigurationRouteArgs {
  const MobileChatConfigurationRouteArgs({this.key, required this.chat});

  final _i31.Key? key;

  final _i32.ChatEntity chat;

  @override
  String toString() {
    return 'MobileChatConfigurationRouteArgs{key: $key, chat: $chat}';
  }
}

/// generated route for
/// [_i14.MobileChatListPage]
class MobileChatListRoute extends _i30.PageRouteInfo<void> {
  const MobileChatListRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileChatListRoute.name, initialChildren: children);

  static const String name = 'MobileChatListRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i14.MobileChatListPage();
    },
  );
}

/// generated route for
/// [_i15.MobileChatPage]
class MobileChatRoute extends _i30.PageRouteInfo<MobileChatRouteArgs> {
  MobileChatRoute({
    _i31.Key? key,
    _i32.ChatEntity? chat,
    _i33.SentinelEntity? sentinel,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileChatRoute.name,
         args: MobileChatRouteArgs(key: key, chat: chat, sentinel: sentinel),
         initialChildren: children,
       );

  static const String name = 'MobileChatRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileChatRouteArgs>(
        orElse: () => const MobileChatRouteArgs(),
      );
      return _i15.MobileChatPage(
        key: args.key,
        chat: args.chat,
        sentinel: args.sentinel,
      );
    },
  );
}

class MobileChatRouteArgs {
  const MobileChatRouteArgs({this.key, this.chat, this.sentinel});

  final _i31.Key? key;

  final _i32.ChatEntity? chat;

  final _i33.SentinelEntity? sentinel;

  @override
  String toString() {
    return 'MobileChatRouteArgs{key: $key, chat: $chat, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i16.MobileDataPage]
class MobileDataRoute extends _i30.PageRouteInfo<void> {
  const MobileDataRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileDataRoute.name, initialChildren: children);

  static const String name = 'MobileDataRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i16.MobileDataPage();
    },
  );
}

/// generated route for
/// [_i17.MobileExperienceDetailPage]
class MobileExperienceDetailRoute
    extends _i30.PageRouteInfo<MobileExperienceDetailRouteArgs> {
  MobileExperienceDetailRoute({
    _i31.Key? key,
    required _i34.ExperienceEntity experience,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileExperienceDetailRoute.name,
         args: MobileExperienceDetailRouteArgs(
           key: key,
           experience: experience,
         ),
         initialChildren: children,
       );

  static const String name = 'MobileExperienceDetailRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileExperienceDetailRouteArgs>();
      return _i17.MobileExperienceDetailPage(
        key: args.key,
        experience: args.experience,
      );
    },
  );
}

class MobileExperienceDetailRouteArgs {
  const MobileExperienceDetailRouteArgs({this.key, required this.experience});

  final _i31.Key? key;

  final _i34.ExperienceEntity experience;

  @override
  String toString() {
    return 'MobileExperienceDetailRouteArgs{key: $key, experience: $experience}';
  }
}

/// generated route for
/// [_i18.MobileExperienceListPage]
class MobileExperienceListRoute extends _i30.PageRouteInfo<void> {
  const MobileExperienceListRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileExperienceListRoute.name, initialChildren: children);

  static const String name = 'MobileExperienceListRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i18.MobileExperienceListPage();
    },
  );
}

/// generated route for
/// [_i19.MobileHomePage]
class MobileHomeRoute extends _i30.PageRouteInfo<void> {
  const MobileHomeRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileHomeRoute.name, initialChildren: children);

  static const String name = 'MobileHomeRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i19.MobileHomePage();
    },
  );
}

/// generated route for
/// [_i20.MobileModelFormPage]
class MobileModelFormRoute
    extends _i30.PageRouteInfo<MobileModelFormRouteArgs> {
  MobileModelFormRoute({
    _i31.Key? key,
    _i35.ModelEntity? model,
    _i36.ProviderEntity? provider,
    List<_i30.PageRouteInfo>? children,
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

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileModelFormRouteArgs>(
        orElse: () => const MobileModelFormRouteArgs(),
      );
      return _i20.MobileModelFormPage(
        key: args.key,
        model: args.model,
        provider: args.provider,
      );
    },
  );
}

class MobileModelFormRouteArgs {
  const MobileModelFormRouteArgs({this.key, this.model, this.provider});

  final _i31.Key? key;

  final _i35.ModelEntity? model;

  final _i36.ProviderEntity? provider;

  @override
  String toString() {
    return 'MobileModelFormRouteArgs{key: $key, model: $model, provider: $provider}';
  }
}

/// generated route for
/// [_i21.MobileProviderFormPage]
class MobileProviderFormRoute
    extends _i30.PageRouteInfo<MobileProviderFormRouteArgs> {
  MobileProviderFormRoute({
    _i31.Key? key,
    required _i36.ProviderEntity provider,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileProviderFormRoute.name,
         args: MobileProviderFormRouteArgs(key: key, provider: provider),
         initialChildren: children,
       );

  static const String name = 'MobileProviderFormRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileProviderFormRouteArgs>();
      return _i21.MobileProviderFormPage(
        key: args.key,
        provider: args.provider,
      );
    },
  );
}

class MobileProviderFormRouteArgs {
  const MobileProviderFormRouteArgs({this.key, required this.provider});

  final _i31.Key? key;

  final _i36.ProviderEntity provider;

  @override
  String toString() {
    return 'MobileProviderFormRouteArgs{key: $key, provider: $provider}';
  }
}

/// generated route for
/// [_i22.MobileProviderListPage]
class MobileProviderListRoute extends _i30.PageRouteInfo<void> {
  const MobileProviderListRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileProviderListRoute.name, initialChildren: children);

  static const String name = 'MobileProviderListRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i22.MobileProviderListPage();
    },
  );
}

/// generated route for
/// [_i23.MobileProviderNamePage]
class MobileProviderNameRoute extends _i30.PageRouteInfo<void> {
  const MobileProviderNameRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileProviderNameRoute.name, initialChildren: children);

  static const String name = 'MobileProviderNameRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i23.MobileProviderNamePage();
    },
  );
}

/// generated route for
/// [_i24.MobileSentinelFormPage]
class MobileSentinelFormRoute
    extends _i30.PageRouteInfo<MobileSentinelFormRouteArgs> {
  MobileSentinelFormRoute({
    _i31.Key? key,
    _i33.SentinelEntity? sentinel,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileSentinelFormRoute.name,
         args: MobileSentinelFormRouteArgs(key: key, sentinel: sentinel),
         initialChildren: children,
       );

  static const String name = 'MobileSentinelFormRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSentinelFormRouteArgs>(
        orElse: () => const MobileSentinelFormRouteArgs(),
      );
      return _i24.MobileSentinelFormPage(
        key: args.key,
        sentinel: args.sentinel,
      );
    },
  );
}

class MobileSentinelFormRouteArgs {
  const MobileSentinelFormRouteArgs({this.key, this.sentinel});

  final _i31.Key? key;

  final _i33.SentinelEntity? sentinel;

  @override
  String toString() {
    return 'MobileSentinelFormRouteArgs{key: $key, sentinel: $sentinel}';
  }
}

/// generated route for
/// [_i25.MobileSentinelListPage]
class MobileSentinelListRoute extends _i30.PageRouteInfo<void> {
  const MobileSentinelListRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileSentinelListRoute.name, initialChildren: children);

  static const String name = 'MobileSentinelListRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i25.MobileSentinelListPage();
    },
  );
}

/// generated route for
/// [_i26.MobileSettingPage]
class MobileSettingRoute extends _i30.PageRouteInfo<void> {
  const MobileSettingRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileSettingRoute.name, initialChildren: children);

  static const String name = 'MobileSettingRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i26.MobileSettingPage();
    },
  );
}

/// generated route for
/// [_i27.MobileSkillDetailPage]
class MobileSkillDetailRoute
    extends _i30.PageRouteInfo<MobileSkillDetailRouteArgs> {
  MobileSkillDetailRoute({
    _i31.Key? key,
    required _i37.Skill skill,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileSkillDetailRoute.name,
         args: MobileSkillDetailRouteArgs(key: key, skill: skill),
         initialChildren: children,
       );

  static const String name = 'MobileSkillDetailRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSkillDetailRouteArgs>();
      return _i27.MobileSkillDetailPage(key: args.key, skill: args.skill);
    },
  );
}

class MobileSkillDetailRouteArgs {
  const MobileSkillDetailRouteArgs({this.key, required this.skill});

  final _i31.Key? key;

  final _i37.Skill skill;

  @override
  String toString() {
    return 'MobileSkillDetailRouteArgs{key: $key, skill: $skill}';
  }
}

/// generated route for
/// [_i28.MobileSkillFormPage]
class MobileSkillFormRoute
    extends _i30.PageRouteInfo<MobileSkillFormRouteArgs> {
  MobileSkillFormRoute({
    _i31.Key? key,
    _i37.Skill? skill,
    List<_i30.PageRouteInfo>? children,
  }) : super(
         MobileSkillFormRoute.name,
         args: MobileSkillFormRouteArgs(key: key, skill: skill),
         initialChildren: children,
       );

  static const String name = 'MobileSkillFormRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MobileSkillFormRouteArgs>(
        orElse: () => const MobileSkillFormRouteArgs(),
      );
      return _i28.MobileSkillFormPage(key: args.key, skill: args.skill);
    },
  );
}

class MobileSkillFormRouteArgs {
  const MobileSkillFormRouteArgs({this.key, this.skill});

  final _i31.Key? key;

  final _i37.Skill? skill;

  @override
  String toString() {
    return 'MobileSkillFormRouteArgs{key: $key, skill: $skill}';
  }
}

/// generated route for
/// [_i29.MobileSkillListPage]
class MobileSkillListRoute extends _i30.PageRouteInfo<void> {
  const MobileSkillListRoute({List<_i30.PageRouteInfo>? children})
    : super(MobileSkillListRoute.name, initialChildren: children);

  static const String name = 'MobileSkillListRoute';

  static _i30.PageInfo page = _i30.PageInfo(
    name,
    builder: (data) {
      return const _i29.MobileSkillListPage();
    },
  );
}
