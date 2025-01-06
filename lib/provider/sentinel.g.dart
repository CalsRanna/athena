// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentinel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sentinelTagsNotifierHash() =>
    r'9e37bba106612e04f41ba2531c4d10a019088caf';

/// See also [SentinelTagsNotifier].
@ProviderFor(SentinelTagsNotifier)
final sentinelTagsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    SentinelTagsNotifier, List<String>>.internal(
  SentinelTagsNotifier.new,
  name: r'sentinelTagsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sentinelTagsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SentinelTagsNotifier = AutoDisposeAsyncNotifier<List<String>>;
String _$chatRelatedSentinelNotifierHash() =>
    r'9991c4890395462fc0e39f8d2453c07fdc8394b7';

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

abstract class _$ChatRelatedSentinelNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Sentinel> {
  late final int chatId;

  FutureOr<Sentinel> build(
    int chatId,
  );
}

/// See also [ChatRelatedSentinelNotifier].
@ProviderFor(ChatRelatedSentinelNotifier)
const chatRelatedSentinelNotifierProvider = ChatRelatedSentinelNotifierFamily();

/// See also [ChatRelatedSentinelNotifier].
class ChatRelatedSentinelNotifierFamily extends Family<AsyncValue<Sentinel>> {
  /// See also [ChatRelatedSentinelNotifier].
  const ChatRelatedSentinelNotifierFamily();

  /// See also [ChatRelatedSentinelNotifier].
  ChatRelatedSentinelNotifierProvider call(
    int chatId,
  ) {
    return ChatRelatedSentinelNotifierProvider(
      chatId,
    );
  }

  @override
  ChatRelatedSentinelNotifierProvider getProviderOverride(
    covariant ChatRelatedSentinelNotifierProvider provider,
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
  String? get name => r'chatRelatedSentinelNotifierProvider';
}

/// See also [ChatRelatedSentinelNotifier].
class ChatRelatedSentinelNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ChatRelatedSentinelNotifier,
        Sentinel> {
  /// See also [ChatRelatedSentinelNotifier].
  ChatRelatedSentinelNotifierProvider(
    int chatId,
  ) : this._internal(
          () => ChatRelatedSentinelNotifier()..chatId = chatId,
          from: chatRelatedSentinelNotifierProvider,
          name: r'chatRelatedSentinelNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatRelatedSentinelNotifierHash,
          dependencies: ChatRelatedSentinelNotifierFamily._dependencies,
          allTransitiveDependencies:
              ChatRelatedSentinelNotifierFamily._allTransitiveDependencies,
          chatId: chatId,
        );

  ChatRelatedSentinelNotifierProvider._internal(
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
  FutureOr<Sentinel> runNotifierBuild(
    covariant ChatRelatedSentinelNotifier notifier,
  ) {
    return notifier.build(
      chatId,
    );
  }

  @override
  Override overrideWith(ChatRelatedSentinelNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatRelatedSentinelNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChatRelatedSentinelNotifier, Sentinel>
      createElement() {
    return _ChatRelatedSentinelNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatRelatedSentinelNotifierProvider &&
        other.chatId == chatId;
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
mixin ChatRelatedSentinelNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<Sentinel> {
  /// The parameter `chatId` of this provider.
  int get chatId;
}

class _ChatRelatedSentinelNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChatRelatedSentinelNotifier,
        Sentinel> with ChatRelatedSentinelNotifierRef {
  _ChatRelatedSentinelNotifierProviderElement(super.provider);

  @override
  int get chatId => (origin as ChatRelatedSentinelNotifierProvider).chatId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
