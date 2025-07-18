// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'2bdda32205e34bbaf7396200f2def983c0196e39';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ChatNotifier extends BuildlessAutoDisposeAsyncNotifier<Chat> {
  late final int id;

  FutureOr<Chat> build(
    int id,
  );
}

/// See also [ChatNotifier].
@ProviderFor(ChatNotifier)
const chatNotifierProvider = ChatNotifierFamily();

/// See also [ChatNotifier].
class ChatNotifierFamily extends Family<AsyncValue<Chat>> {
  /// See also [ChatNotifier].
  const ChatNotifierFamily();

  /// See also [ChatNotifier].
  ChatNotifierProvider call(
    int id,
  ) {
    return ChatNotifierProvider(
      id,
    );
  }

  @override
  ChatNotifierProvider getProviderOverride(
    covariant ChatNotifierProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatNotifierProvider';
}

/// See also [ChatNotifier].
class ChatNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ChatNotifier, Chat> {
  /// See also [ChatNotifier].
  ChatNotifierProvider(
    int id,
  ) : this._internal(
          () => ChatNotifier()..id = id,
          from: chatNotifierProvider,
          name: r'chatNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatNotifierHash,
          dependencies: ChatNotifierFamily._dependencies,
          allTransitiveDependencies:
              ChatNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  ChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  FutureOr<Chat> runNotifierBuild(
    covariant ChatNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(ChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatNotifierProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ChatNotifier, Chat> createElement() {
    return _ChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatNotifierRef on AutoDisposeAsyncNotifierProviderRef<Chat> {
  /// The parameter `id` of this provider.
  int get id;
}

class _ChatNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChatNotifier, Chat>
    with ChatNotifierRef {
  _ChatNotifierProviderElement(super.provider);

  @override
  int get id => (origin as ChatNotifierProvider).id;
}

String _$chatsNotifierHash() => r'80e4bd0d7b0206ce3b4803779e56614c1cc89e3b';

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
String _$messagesNotifierHash() => r'd8f14245e8f39f4186be1aa91a97b5d7d2f9708a';

abstract class _$MessagesNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<Message>> {
  late final int chatId;

  FutureOr<List<Message>> build(
    int chatId,
  );
}

/// See also [MessagesNotifier].
@ProviderFor(MessagesNotifier)
const messagesNotifierProvider = MessagesNotifierFamily();

/// See also [MessagesNotifier].
class MessagesNotifierFamily extends Family<AsyncValue<List<Message>>> {
  /// See also [MessagesNotifier].
  const MessagesNotifierFamily();

  /// See also [MessagesNotifier].
  MessagesNotifierProvider call(
    int chatId,
  ) {
    return MessagesNotifierProvider(
      chatId,
    );
  }

  @override
  MessagesNotifierProvider getProviderOverride(
    covariant MessagesNotifierProvider provider,
  ) {
    return call(
      provider.chatId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'messagesNotifierProvider';
}

/// See also [MessagesNotifier].
class MessagesNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    MessagesNotifier, List<Message>> {
  /// See also [MessagesNotifier].
  MessagesNotifierProvider(
    int chatId,
  ) : this._internal(
          () => MessagesNotifier()..chatId = chatId,
          from: messagesNotifierProvider,
          name: r'messagesNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$messagesNotifierHash,
          dependencies: MessagesNotifierFamily._dependencies,
          allTransitiveDependencies:
              MessagesNotifierFamily._allTransitiveDependencies,
          chatId: chatId,
        );

  MessagesNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.chatId,
  }) : super.internal();

  final int chatId;

  @override
  FutureOr<List<Message>> runNotifierBuild(
    covariant MessagesNotifier notifier,
  ) {
    return notifier.build(
      chatId,
    );
  }

  @override
  Override overrideWith(MessagesNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MessagesNotifierProvider._internal(
        () => create()..chatId = chatId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        chatId: chatId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MessagesNotifier, List<Message>>
      createElement() {
    return _MessagesNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagesNotifierProvider && other.chatId == chatId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, chatId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MessagesNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<List<Message>> {
  /// The parameter `chatId` of this provider.
  int get chatId;
}

class _MessagesNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<MessagesNotifier,
        List<Message>> with MessagesNotifierRef {
  _MessagesNotifierProviderElement(super.provider);

  @override
  int get chatId => (origin as MessagesNotifierProvider).chatId;
}

String _$recentChatsNotifierHash() =>
    r'58c8ff704e9454b2ec9b6fb1f97e7a25d78c6bfb';

/// See also [RecentChatsNotifier].
@ProviderFor(RecentChatsNotifier)
final recentChatsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<RecentChatsNotifier, List<Chat>>.internal(
  RecentChatsNotifier.new,
  name: r'recentChatsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recentChatsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecentChatsNotifier = AutoDisposeAsyncNotifier<List<Chat>>;
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
