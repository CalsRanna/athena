// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'a2f62ee121cee77c807eeaacb4df7f421102b81e';

/// See also [ChatNotifier].
@ProviderFor(ChatNotifier)
final chatNotifierProvider =
    AutoDisposeNotifierProvider<ChatNotifier, Chat>.internal(
  ChatNotifier.new,
  name: r'chatNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatNotifier = AutoDisposeNotifier<Chat>;
String _$chatsNotifierHash() => r'62a79ba5f8ba346c42af526569ac5c43efe6a1c2';

/// See also [ChatsNotifier].
@ProviderFor(ChatsNotifier)
final chatsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatsNotifier, List<Chat>>.internal(
  ChatsNotifier.new,
  name: r'chatsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatsNotifier = AutoDisposeAsyncNotifier<List<Chat>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
