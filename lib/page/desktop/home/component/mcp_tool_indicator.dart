import 'package:athena/provider/mcp.dart';
import 'package:athena/vendor/mcp/tool.dart';
import 'package:athena/widget/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopMcpToolIndicator extends ConsumerWidget {
  const DesktopMcpToolIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = mcpToolsNotifierProvider;
    var state = ref.watch(provider);
    return switch (state) {
      AsyncData(:final value) => _buildData(value),
      AsyncLoading() => _buildLoading(),
      AsyncError(:final error) => _buildError(error),
      _ => const SizedBox(),
    };
  }

  Widget _buildData(List<McpTool> tools) {
    return AthenaTag.small(text: '${tools.length} MCP tools available');
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 16,
      width: 16,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildError(Object error) {
    return AthenaTag.small(text: error.toString());
  }
}
