// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$enabledProvidersNotifierHash() =>
    r'297475e9b794d492190a54a75fa57f411184090c';

/// See also [EnabledProvidersNotifier].
@ProviderFor(EnabledProvidersNotifier)
final enabledProvidersNotifierProvider = AutoDisposeAsyncNotifierProvider<
    EnabledProvidersNotifier, List<schema.Provider>>.internal(
  EnabledProvidersNotifier.new,
  name: r'enabledProvidersNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$enabledProvidersNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EnabledProvidersNotifier
    = AutoDisposeAsyncNotifier<List<schema.Provider>>;
String _$providersNotifierHash() => r'ea0190eb56c100c1170829dc54690f5cf1f90828';

/// See also [ProvidersNotifier].
@ProviderFor(ProvidersNotifier)
final providersNotifierProvider = AutoDisposeAsyncNotifierProvider<
    ProvidersNotifier, List<schema.Provider>>.internal(
  ProvidersNotifier.new,
  name: r'providersNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$providersNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProvidersNotifier = AutoDisposeAsyncNotifier<List<schema.Provider>>;
String _$providerNotifierHash() => r'84a1e37b71ede869d7b72dbf3c5be36682449e9e';

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

abstract class _$ProviderNotifier
    extends BuildlessAutoDisposeAsyncNotifier<schema.Provider> {
  late final int id;

  FutureOr<schema.Provider> build(
    int id,
  );
}

/// See also [ProviderNotifier].
@ProviderFor(ProviderNotifier)
const providerNotifierProvider = ProviderNotifierFamily();

/// See also [ProviderNotifier].
class ProviderNotifierFamily extends Family<AsyncValue<schema.Provider>> {
  /// See also [ProviderNotifier].
  const ProviderNotifierFamily();

  /// See also [ProviderNotifier].
  ProviderNotifierProvider call(
    int id,
  ) {
    return ProviderNotifierProvider(
      id,
    );
  }

  @override
  ProviderNotifierProvider getProviderOverride(
    covariant ProviderNotifierProvider provider,
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
  String? get name => r'providerNotifierProvider';
}

/// See also [ProviderNotifier].
class ProviderNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ProviderNotifier, schema.Provider> {
  /// See also [ProviderNotifier].
  ProviderNotifierProvider(
    int id,
  ) : this._internal(
          () => ProviderNotifier()..id = id,
          from: providerNotifierProvider,
          name: r'providerNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$providerNotifierHash,
          dependencies: ProviderNotifierFamily._dependencies,
          allTransitiveDependencies:
              ProviderNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  ProviderNotifierProvider._internal(
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
  FutureOr<schema.Provider> runNotifierBuild(
    covariant ProviderNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(ProviderNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProviderNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ProviderNotifier, schema.Provider>
      createElement() {
    return _ProviderNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderNotifierProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ProviderNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<schema.Provider> {
  /// The parameter `id` of this provider.
  int get id;
}

class _ProviderNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ProviderNotifier,
        schema.Provider> with ProviderNotifierRef {
  _ProviderNotifierProviderElement(super.provider);

  @override
  int get id => (origin as ProviderNotifierProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
