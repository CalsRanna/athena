// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'155aa5f3fd6ea60ad4271654f1aa88d7069c907a';

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
String _$chatsNotifierHash() => r'd4af228f6d58af48ec0ae005e25e4be2f1df1f47';

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
String _$messagesNotifierHash() => r'edc44f5caca6be5f1d93dcf06b186cf45dc92455';

/// See also [MessagesNotifier].
@ProviderFor(MessagesNotifier)
final messagesNotifierProvider =
    AutoDisposeAsyncNotifierProvider<MessagesNotifier, List<Message>>.internal(
  MessagesNotifier.new,
  name: r'messagesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$messagesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MessagesNotifier = AutoDisposeAsyncNotifier<List<Message>>;
String _$sentinelNotifierHash() => r'a6d3e8fc2d31a0a5a128065f4ec9e36e1b126e72';

/// See also [SentinelNotifier].
@ProviderFor(SentinelNotifier)
final sentinelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SentinelNotifier, Sentinel>.internal(
  SentinelNotifier.new,
  name: r'sentinelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sentinelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SentinelNotifier = AutoDisposeAsyncNotifier<Sentinel>;
String _$sentinelsNotifierHash() => r'347ec40369234689e3f8abe420e65c173e30abae';

/// See also [SentinelsNotifier].
@ProviderFor(SentinelsNotifier)
final sentinelsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    SentinelsNotifier, List<Sentinel>>.internal(
  SentinelsNotifier.new,
  name: r'sentinelsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sentinelsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SentinelsNotifier = AutoDisposeAsyncNotifier<List<Sentinel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
