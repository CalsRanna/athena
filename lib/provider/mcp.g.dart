// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mcpToolsNotifierHash() => r'ceb9151d54cf555bdcea74c50919bd7633771f0e';

/// See also [McpToolsNotifier].
@ProviderFor(McpToolsNotifier)
final mcpToolsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<McpToolsNotifier, List<Tool>>.internal(
  McpToolsNotifier.new,
  name: r'mcpToolsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mcpToolsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$McpToolsNotifier = AutoDisposeAsyncNotifier<List<Tool>>;
String _$mcpConnectionsNotifierHash() =>
    r'0c6dd74d3b283b2671e2af8c482a1e2107ea3ee0';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
