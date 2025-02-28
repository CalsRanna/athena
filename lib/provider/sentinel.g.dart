// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentinel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$defaultSentinelNotifierHash() =>
    r'ff5c49a74c5ca18ee09bf544b76daa1223027809';

/// See also [DefaultSentinelNotifier].
@ProviderFor(DefaultSentinelNotifier)
final defaultSentinelNotifierProvider = AutoDisposeAsyncNotifierProvider<
    DefaultSentinelNotifier, Sentinel>.internal(
  DefaultSentinelNotifier.new,
  name: r'defaultSentinelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$defaultSentinelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DefaultSentinelNotifier = AutoDisposeAsyncNotifier<Sentinel>;
String _$sentinelNotifierHash() => r'67bc5f7d80809539a5541d6c0e0d7e82dfd43c1a';

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

abstract class _$SentinelNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Sentinel> {
  late final int id;

  FutureOr<Sentinel> build(
    int id,
  );
}

/// See also [SentinelNotifier].
@ProviderFor(SentinelNotifier)
const sentinelNotifierProvider = SentinelNotifierFamily();

/// See also [SentinelNotifier].
class SentinelNotifierFamily extends Family<AsyncValue<Sentinel>> {
  /// See also [SentinelNotifier].
  const SentinelNotifierFamily();

  /// See also [SentinelNotifier].
  SentinelNotifierProvider call(
    int id,
  ) {
    return SentinelNotifierProvider(
      id,
    );
  }

  @override
  SentinelNotifierProvider getProviderOverride(
    covariant SentinelNotifierProvider provider,
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
  String? get name => r'sentinelNotifierProvider';
}

/// See also [SentinelNotifier].
class SentinelNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<SentinelNotifier, Sentinel> {
  /// See also [SentinelNotifier].
  SentinelNotifierProvider(
    int id,
  ) : this._internal(
          () => SentinelNotifier()..id = id,
          from: sentinelNotifierProvider,
          name: r'sentinelNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sentinelNotifierHash,
          dependencies: SentinelNotifierFamily._dependencies,
          allTransitiveDependencies:
              SentinelNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  SentinelNotifierProvider._internal(
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
  FutureOr<Sentinel> runNotifierBuild(
    covariant SentinelNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(SentinelNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SentinelNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<SentinelNotifier, Sentinel>
      createElement() {
    return _SentinelNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SentinelNotifierProvider && other.id == id;
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
mixin SentinelNotifierRef on AutoDisposeAsyncNotifierProviderRef<Sentinel> {
  /// The parameter `id` of this provider.
  int get id;
}

class _SentinelNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SentinelNotifier, Sentinel>
    with SentinelNotifierRef {
  _SentinelNotifierProviderElement(super.provider);

  @override
  int get id => (origin as SentinelNotifierProvider).id;
}

String _$sentinelsNotifierHash() => r'a0e521a3c64684cf610f6d8fce2417f5b8471fdc';

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
String _$sentinelTagsNotifierHash() =>
    r'c18e92cde8c21bafb05982350a696a496a43acfe';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
