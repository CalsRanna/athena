// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'523ec3ac362e67a4d0c74c0271deb2089209e821';

/// See also [ChatNotifier].
@ProviderFor(ChatNotifier)
final chatNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatNotifier, Chat>.internal(
  ChatNotifier.new,
  name: r'chatNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatNotifier = AutoDisposeAsyncNotifier<Chat>;
String _$chatsNotifierHash() => r'8bdade86752670b533e1317710213c400f51d952';

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
String _$messagesNotifierHash() => r'891a5baed42fc941248eac87dcde6aeaa2a94a55';

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
String _$sentinelNotifierHash() => r'ae8c459207084268f9f60b7c179fe4bcd8e5a714';

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
String _$sentinelsNotifierHash() => r'59370fafcfed0b39dacfb9e1fef8bfad9f5db2c8';

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
String _$streamingNotifierHash() => r'cab3b5f93f1a0c2c777ad3873b14c2e3c9c5777f';

/// See also [StreamingNotifier].
@ProviderFor(StreamingNotifier)
final streamingNotifierProvider =
    AutoDisposeNotifierProvider<StreamingNotifier, bool>.internal(
  StreamingNotifier.new,
  name: r'streamingNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$streamingNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StreamingNotifier = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
