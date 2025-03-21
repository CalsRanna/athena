// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serversNotifierHash() => r'04b9133abd26fb60eecb4e849b02fd8142c7478b';

/// See also [ServersNotifier].
@ProviderFor(ServersNotifier)
final serversNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ServersNotifier, List<Server>>.internal(
  ServersNotifier.new,
  name: r'serversNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$serversNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServersNotifier = AutoDisposeAsyncNotifier<List<Server>>;
String _$serverNotifierHash() => r'33712914d636dde2424c910ac8c074daae8d8097';

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

abstract class _$ServerNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Server> {
  late final int id;

  FutureOr<Server> build(
    int id,
  );
}

/// See also [ServerNotifier].
@ProviderFor(ServerNotifier)
const serverNotifierProvider = ServerNotifierFamily();

/// See also [ServerNotifier].
class ServerNotifierFamily extends Family<AsyncValue<Server>> {
  /// See also [ServerNotifier].
  const ServerNotifierFamily();

  /// See also [ServerNotifier].
  ServerNotifierProvider call(
    int id,
  ) {
    return ServerNotifierProvider(
      id,
    );
  }

  @override
  ServerNotifierProvider getProviderOverride(
    covariant ServerNotifierProvider provider,
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
  String? get name => r'serverNotifierProvider';
}

/// See also [ServerNotifier].
class ServerNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ServerNotifier, Server> {
  /// See also [ServerNotifier].
  ServerNotifierProvider(
    int id,
  ) : this._internal(
          () => ServerNotifier()..id = id,
          from: serverNotifierProvider,
          name: r'serverNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$serverNotifierHash,
          dependencies: ServerNotifierFamily._dependencies,
          allTransitiveDependencies:
              ServerNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  ServerNotifierProvider._internal(
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
  FutureOr<Server> runNotifierBuild(
    covariant ServerNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(ServerNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ServerNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ServerNotifier, Server>
      createElement() {
    return _ServerNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ServerNotifierProvider && other.id == id;
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
mixin ServerNotifierRef on AutoDisposeAsyncNotifierProviderRef<Server> {
  /// The parameter `id` of this provider.
  int get id;
}

class _ServerNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ServerNotifier, Server>
    with ServerNotifierRef {
  _ServerNotifierProviderElement(super.provider);

  @override
  int get id => (origin as ServerNotifierProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
