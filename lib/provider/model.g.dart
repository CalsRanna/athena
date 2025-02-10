// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modelNotifierHash() => r'69431644ac75ce147949604714669fca428dad92';

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

abstract class _$ModelNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Model> {
  late final String value;

  FutureOr<Model> build(
    String value,
  );
}

/// See also [ModelNotifier].
@ProviderFor(ModelNotifier)
const modelNotifierProvider = ModelNotifierFamily();

/// See also [ModelNotifier].
class ModelNotifierFamily extends Family<AsyncValue<Model>> {
  /// See also [ModelNotifier].
  const ModelNotifierFamily();

  /// See also [ModelNotifier].
  ModelNotifierProvider call(
    String value,
  ) {
    return ModelNotifierProvider(
      value,
    );
  }

  @override
  ModelNotifierProvider getProviderOverride(
    covariant ModelNotifierProvider provider,
  ) {
    return call(
      provider.value,
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
  String? get name => r'modelNotifierProvider';
}

/// See also [ModelNotifier].
class ModelNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ModelNotifier, Model> {
  /// See also [ModelNotifier].
  ModelNotifierProvider(
    String value,
  ) : this._internal(
          () => ModelNotifier()..value = value,
          from: modelNotifierProvider,
          name: r'modelNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$modelNotifierHash,
          dependencies: ModelNotifierFamily._dependencies,
          allTransitiveDependencies:
              ModelNotifierFamily._allTransitiveDependencies,
          value: value,
        );

  ModelNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.value,
  }) : super.internal();

  final String value;

  @override
  FutureOr<Model> runNotifierBuild(
    covariant ModelNotifier notifier,
  ) {
    return notifier.build(
      value,
    );
  }

  @override
  Override overrideWith(ModelNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ModelNotifierProvider._internal(
        () => create()..value = value,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        value: value,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ModelNotifier, Model>
      createElement() {
    return _ModelNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ModelNotifierProvider && other.value == value;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, value.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ModelNotifierRef on AutoDisposeAsyncNotifierProviderRef<Model> {
  /// The parameter `value` of this provider.
  String get value;
}

class _ModelNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ModelNotifier, Model>
    with ModelNotifierRef {
  _ModelNotifierProviderElement(super.provider);

  @override
  String get value => (origin as ModelNotifierProvider).value;
}

String _$modelsForNotifierHash() => r'eccf7bfcb9ca012292a40b317978be0b8dfb97a9';

abstract class _$ModelsForNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<Model>> {
  late final int providerId;

  FutureOr<List<Model>> build(
    int providerId,
  );
}

/// See also [ModelsForNotifier].
@ProviderFor(ModelsForNotifier)
const modelsForNotifierProvider = ModelsForNotifierFamily();

/// See also [ModelsForNotifier].
class ModelsForNotifierFamily extends Family<AsyncValue<List<Model>>> {
  /// See also [ModelsForNotifier].
  const ModelsForNotifierFamily();

  /// See also [ModelsForNotifier].
  ModelsForNotifierProvider call(
    int providerId,
  ) {
    return ModelsForNotifierProvider(
      providerId,
    );
  }

  @override
  ModelsForNotifierProvider getProviderOverride(
    covariant ModelsForNotifierProvider provider,
  ) {
    return call(
      provider.providerId,
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
  String? get name => r'modelsForNotifierProvider';
}

/// See also [ModelsForNotifier].
class ModelsForNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ModelsForNotifier, List<Model>> {
  /// See also [ModelsForNotifier].
  ModelsForNotifierProvider(
    int providerId,
  ) : this._internal(
          () => ModelsForNotifier()..providerId = providerId,
          from: modelsForNotifierProvider,
          name: r'modelsForNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$modelsForNotifierHash,
          dependencies: ModelsForNotifierFamily._dependencies,
          allTransitiveDependencies:
              ModelsForNotifierFamily._allTransitiveDependencies,
          providerId: providerId,
        );

  ModelsForNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.providerId,
  }) : super.internal();

  final int providerId;

  @override
  FutureOr<List<Model>> runNotifierBuild(
    covariant ModelsForNotifier notifier,
  ) {
    return notifier.build(
      providerId,
    );
  }

  @override
  Override overrideWith(ModelsForNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ModelsForNotifierProvider._internal(
        () => create()..providerId = providerId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        providerId: providerId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ModelsForNotifier, List<Model>>
      createElement() {
    return _ModelsForNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ModelsForNotifierProvider && other.providerId == providerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, providerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ModelsForNotifierRef on AutoDisposeAsyncNotifierProviderRef<List<Model>> {
  /// The parameter `providerId` of this provider.
  int get providerId;
}

class _ModelsForNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ModelsForNotifier,
        List<Model>> with ModelsForNotifierRef {
  _ModelsForNotifierProviderElement(super.provider);

  @override
  int get providerId => (origin as ModelsForNotifierProvider).providerId;
}

String _$modelsNotifierHash() => r'a7426ff9c75bc9f0b77eaf270009f5fdaa13bfa6';

/// See also [ModelsNotifier].
@ProviderFor(ModelsNotifier)
final modelsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ModelsNotifier, List<Model>>.internal(
  ModelsNotifier.new,
  name: r'modelsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$modelsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ModelsNotifier = AutoDisposeAsyncNotifier<List<Model>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
