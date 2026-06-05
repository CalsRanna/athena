import 'dart:async';
import 'dart:convert';

import 'package:athena/agent/cancel_token.dart';
import 'package:athena/agent/permission/permission_service.dart';
import 'package:athena/agent/tool/url_safety.dart';
import 'package:athena/router/router.dart';
import 'package:athena/util/tool_args_formatter.dart';
import 'package:athena/widget/permission_dialog.dart';

/// 权限审批交互的编排逻辑，从 ChatViewModel 抽出以缩减其职责面（审计 A6）。
///
/// 纯编排：参数解析 → 危险判定 → 弹窗 → 规则持久化。
class PermissionInteractor {
  final PermissionService _permissionService;

  PermissionInteractor({required PermissionService permissionService})
      : _permissionService = permissionService;

  Future<bool> askPermission({
    required String toolName,
    required String arguments,
    required CancelToken cancelToken,
  }) async {
    if (cancelToken.isCancelled) return false;
    Map<String, dynamic> args;
    try {
      args = jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      args = {};
    }
    final description = formatToolArgsForApproval(toolName, arguments);
    final ruleDesc =
        _permissionService.generateRuleDescription(toolName, args);
    final isDangerous = _permissionService.isDangerous(toolName, args);
    final isFileRule = const {
      'file_read',
      'file_write',
      'file_update',
      'file_delete',
      'search',
      'list_directory',
    }.contains(toolName);

    final warning = toolName == 'web_fetch'
        ? webFetchApprovalWarning(args['url'] as String?)
        : null;

    final dialogFuture = showPermissionDialog(
      toolName: toolName,
      description: description,
      ruleDescription: ruleDesc,
      allowPersist: !isDangerous,
      isFileRule: isFileRule,
      warning: warning,
    );

    final result = await Future.any<PermissionDialogResult>([
      dialogFuture,
      cancelToken.whenCancelled.then((_) {
        final nav = router.navigatorKey.currentState;
        if (nav?.canPop() ?? false) nav!.pop();
        return const PermissionDialogResult(approved: false, persist: false);
      }),
    ]);

    if (result.approved && result.persist) {
      final rule = _permissionService.generateRule(
        toolName,
        args,
        recursive: result.recursive,
      );
      await _permissionService.persistRule(rule);
    }
    return result.approved;
  }
}
