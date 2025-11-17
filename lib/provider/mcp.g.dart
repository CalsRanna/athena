// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mcpConnectionsNotifierHash() =>
    r'bad6c17136897eaf5311004d10ec88ad8e004810';

/// See also [McpConnectionsNotifier].
@ProviderFor(McpConnectionsNotifier)
final mcpConnectionsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    McpConnectionsNotifier, Map<String, ServerConnection>>.internal(
  McpConnectionsNotifier.new,
  name: r'mcpConnectionsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mcpConnectionsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$McpConnectionsNotifier
    = AutoDisposeAsyncNotifier<Map<String, ServerConnection>>;
String _$mcpToolsNotifierHash() => r'90f7bd5335861a8823d769017178424225311672';

/// See also [McpToolsNotifier].
@ProviderFor(McpToolsNotifier)
final mcpToolsNotifierProvider = AutoDisposeAsyncNotifierProvider<
    McpToolsNotifier, Map<String, List<Tool>>>.internal(
  McpToolsNotifier.new,
  name: r'mcpToolsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mcpToolsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$McpToolsNotifier = AutoDisposeAsyncNotifier<Map<String, List<Tool>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
