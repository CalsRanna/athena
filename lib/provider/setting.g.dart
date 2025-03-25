// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$settingNotifierHash() => r'3ccca551de9860fb5bd82d9549db4124aca06a62';

/// See also [SettingNotifier].
@ProviderFor(SettingNotifier)
final settingNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SettingNotifier, Setting>.internal(
  SettingNotifier.new,
  name: r'settingNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SettingNotifier = AutoDisposeAsyncNotifier<Setting>;
String _$developerModeNotifierHash() =>
    r'fac5afa3099d7cfb7a93cff0d34e2e1302652b75';

/// See also [DeveloperModeNotifier].
@ProviderFor(DeveloperModeNotifier)
final developerModeNotifierProvider =
    NotifierProvider<DeveloperModeNotifier, bool>.internal(
  DeveloperModeNotifier.new,
  name: r'developerModeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$developerModeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeveloperModeNotifier = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
