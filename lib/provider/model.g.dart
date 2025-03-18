// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatModelNotifierHash() => r'04d16949a131e2ac33cfda6da33d379362908323';

/// See also [ChatModelNotifier].
@ProviderFor(ChatModelNotifier)
final chatModelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatModelNotifier, Model>.internal(
  ChatModelNotifier.new,
  name: r'chatModelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatModelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatModelNotifier = AutoDisposeAsyncNotifier<Model>;
String _$chatNamingModelNotifierHash() =>
    r'8acc4dabaec3410c43aca30d5bed30192604edb9';

/// See also [ChatNamingModelNotifier].
@ProviderFor(ChatNamingModelNotifier)
final chatNamingModelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatNamingModelNotifier, Model>.internal(
  ChatNamingModelNotifier.new,
  name: r'chatNamingModelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatNamingModelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatNamingModelNotifier = AutoDisposeAsyncNotifier<Model>;
String _$chatSearchDecisionModelNotifierHash() =>
    r'775c1b885d97c2740693b588bc6323023964f8ab';

/// See also [ChatSearchDecisionModelNotifier].
@ProviderFor(ChatSearchDecisionModelNotifier)
final chatSearchDecisionModelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatSearchDecisionModelNotifier,
        Model>.internal(
  ChatSearchDecisionModelNotifier.new,
  name: r'chatSearchDecisionModelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatSearchDecisionModelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatSearchDecisionModelNotifier = AutoDisposeAsyncNotifier<Model>;
String _$translatingModelNotifierHash() =>
    r'adfeb1f1cf2db3448533a03c739c7b720d82b53b';

/// See also [TranslatingModelNotifier].
@ProviderFor(TranslatingModelNotifier)
final translatingModelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TranslatingModelNotifier, Model>.internal(
  TranslatingModelNotifier.new,
  name: r'translatingModelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translatingModelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TranslatingModelNotifier = AutoDisposeAsyncNotifier<Model>;
String _$enabledModelsForNotifierHash() =>
    r'5f36926b326aa2512486cc21ca44f6acec1dc17b';

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

abstract class _$EnabledModelsForNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<Model>> {
  late final int providerId;

  FutureOr<List<Model>> build(
    int providerId,
  );
}

/// See also [EnabledModelsForNotifier].
@ProviderFor(EnabledModelsForNotifier)
const enabledModelsForNotifierProvider = EnabledModelsForNotifierFamily();

/// See also [EnabledModelsForNotifier].
class EnabledModelsForNotifierFamily extends Family<AsyncValue<List<Model>>> {
  /// See also [EnabledModelsForNotifier].
  const EnabledModelsForNotifierFamily();

  /// See also [EnabledModelsForNotifier].
  EnabledModelsForNotifierProvider call(
    int providerId,
  ) {
    return EnabledModelsForNotifierProvider(
      providerId,
    );
  }

  @override
  EnabledModelsForNotifierProvider getProviderOverride(
    covariant EnabledModelsForNotifierProvider provider,
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
  String? get name => r'enabledModelsForNotifierProvider';
}

/// See also [EnabledModelsForNotifier].
class EnabledModelsForNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<EnabledModelsForNotifier,
        List<Model>> {
  /// See also [EnabledModelsForNotifier].
  EnabledModelsForNotifierProvider(
    int providerId,
  ) : this._internal(
          () => EnabledModelsForNotifier()..providerId = providerId,
          from: enabledModelsForNotifierProvider,
          name: r'enabledModelsForNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$enabledModelsForNotifierHash,
          dependencies: EnabledModelsForNotifierFamily._dependencies,
          allTransitiveDependencies:
              EnabledModelsForNotifierFamily._allTransitiveDependencies,
          providerId: providerId,
        );

  EnabledModelsForNotifierProvider._internal(
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
    covariant EnabledModelsForNotifier notifier,
  ) {
    return notifier.build(
      providerId,
    );
  }

  @override
  Override overrideWith(EnabledModelsForNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: EnabledModelsForNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<EnabledModelsForNotifier, List<Model>>
      createElement() {
    return _EnabledModelsForNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EnabledModelsForNotifierProvider &&
        other.providerId == providerId;
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
mixin EnabledModelsForNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<List<Model>> {
  /// The parameter `providerId` of this provider.
  int get providerId;
}

class _EnabledModelsForNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<EnabledModelsForNotifier,
        List<Model>> with EnabledModelsForNotifierRef {
  _EnabledModelsForNotifierProviderElement(super.provider);

  @override
  int get providerId => (origin as EnabledModelsForNotifierProvider).providerId;
}

String _$groupedEnabledModelsNotifierHash() =>
    r'ed8a08e8c485f4b26100f90510aea260622dda24';

/// See also [GroupedEnabledModelsNotifier].
@ProviderFor(GroupedEnabledModelsNotifier)
final groupedEnabledModelsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    GroupedEnabledModelsNotifier, Map<String, List<Model>>>.internal(
  GroupedEnabledModelsNotifier.new,
  name: r'groupedEnabledModelsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$groupedEnabledModelsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GroupedEnabledModelsNotifier
    = AutoDisposeAsyncNotifier<Map<String, List<Model>>>;
String _$modelNotifierHash() => r'9d0db6371e4fde7da996f158b53a70e0fa909861';

abstract class _$ModelNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Model> {
  late final int id;

  FutureOr<Model> build(
    int id,
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
    int id,
  ) {
    return ModelNotifierProvider(
      id,
    );
  }

  @override
  ModelNotifierProvider getProviderOverride(
    covariant ModelNotifierProvider provider,
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
  String? get name => r'modelNotifierProvider';
}

/// See also [ModelNotifier].
class ModelNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ModelNotifier, Model> {
  /// See also [ModelNotifier].
  ModelNotifierProvider(
    int id,
  ) : this._internal(
          () => ModelNotifier()..id = id,
          from: modelNotifierProvider,
          name: r'modelNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$modelNotifierHash,
          dependencies: ModelNotifierFamily._dependencies,
          allTransitiveDependencies:
              ModelNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  ModelNotifierProvider._internal(
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
  FutureOr<Model> runNotifierBuild(
    covariant ModelNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(ModelNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ModelNotifierProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ModelNotifier, Model>
      createElement() {
    return _ModelNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ModelNotifierProvider && other.id == id;
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
mixin ModelNotifierRef on AutoDisposeAsyncNotifierProviderRef<Model> {
  /// The parameter `id` of this provider.
  int get id;
}

class _ModelNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ModelNotifier, Model>
    with ModelNotifierRef {
  _ModelNotifierProviderElement(super.provider);

  @override
  int get id => (origin as ModelNotifierProvider).id;
}

String _$modelsForNotifierHash() => r'f210bd2dd0ce6139deed295e29c3b20c764aff52';

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

String _$sentinelMetaGenerationModelNotifierHash() =>
    r'632b994ab435b3aa1520249e5a82d8b7752cb8dc';

/// See also [SentinelMetaGenerationModelNotifier].
@ProviderFor(SentinelMetaGenerationModelNotifier)
final sentinelMetaGenerationModelNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SentinelMetaGenerationModelNotifier,
        Model>.internal(
  SentinelMetaGenerationModelNotifier.new,
  name: r'sentinelMetaGenerationModelNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sentinelMetaGenerationModelNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SentinelMetaGenerationModelNotifier = AutoDisposeAsyncNotifier<Model>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
