// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatNotifierHash() => r'64074eb12108b7b133dfa7e767fb37c623910cc2';

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
  late final int? sentinelId;

  FutureOr<Chat> build(
    int id, {
    int? sentinelId,
  });
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
    int id, {
    int? sentinelId,
  }) {
    return ChatNotifierProvider(
      id,
      sentinelId: sentinelId,
    );
  }

  @override
  ChatNotifierProvider getProviderOverride(
    covariant ChatNotifierProvider provider,
  ) {
    return call(
      provider.id,
      sentinelId: provider.sentinelId,
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
    int id, {
    int? sentinelId,
  }) : this._internal(
          () => ChatNotifier()
            ..id = id
            ..sentinelId = sentinelId,
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
          sentinelId: sentinelId,
        );

  ChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.sentinelId,
  }) : super.internal();

  final int id;
  final int? sentinelId;

  @override
  FutureOr<Chat> runNotifierBuild(
    covariant ChatNotifier notifier,
  ) {
    return notifier.build(
      id,
      sentinelId: sentinelId,
    );
  }

  @override
  Override overrideWith(ChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatNotifierProvider._internal(
        () => create()
          ..id = id
          ..sentinelId = sentinelId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        sentinelId: sentinelId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ChatNotifier, Chat> createElement() {
    return _ChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider &&
        other.id == id &&
        other.sentinelId == sentinelId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, sentinelId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatNotifierRef on AutoDisposeAsyncNotifierProviderRef<Chat> {
  /// The parameter `id` of this provider.
  int get id;

  /// The parameter `sentinelId` of this provider.
  int? get sentinelId;
}

class _ChatNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChatNotifier, Chat>
    with ChatNotifierRef {
  _ChatNotifierProviderElement(super.provider);

  @override
  int get id => (origin as ChatNotifierProvider).id;
  @override
  int? get sentinelId => (origin as ChatNotifierProvider).sentinelId;
}

String _$chatsNotifierHash() => r'3fb86ebd3f56224c4aacf44eed903a8824426e36';

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
String _$recentChatsNotifierHash() =>
    r'b5cefaffdaaf577fb09e341d61e76c1264b9d501';

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
String _$messagesNotifierHash() => r'608f800e8f51fea192a3e70acf4420525a58d33b';

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
