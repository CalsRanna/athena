// 对 Dart 文件执行 analysis server 的 edit.sortMembers，与编辑器里的
// “Sort Members”（LSP 的 source.sortMembers code action）是同一实现：
// 排序 import、顶层声明和类成员，不负责格式化。
//
// 用法：
//   dart run tool/sort_members.dart             # 处理仓库内所有 Dart 文件
//   dart run tool/sort_members.dart <路径>...   # 只处理指定的文件或目录
//
// 跳过生成目录（.dart_tool / build / .git）与生成文件（*.g.dart 等）。
// 重复执行是幂等的；有语法错误的文件会被跳过，并在最后列出。

import 'dart:io';

import 'package:analysis_server_lib/analysis_server_lib.dart';

Future<void> main(List<String> arguments) async {
  final projectRoot = File.fromUri(Platform.script).parent.parent.path;
  final targets = arguments.isEmpty
      ? [projectRoot]
      : arguments.map((path) => File(path).absolute.path).toList();
  final files = _collectDartFiles(targets).toList()..sort();
  if (files.isEmpty) {
    stdout.writeln('没有找到可处理的 Dart 文件。');
    return;
  }

  stdout.writeln('共 ${files.length} 个 Dart 文件，正在启动 analysis server…');
  final server = await AnalysisServer.create();
  final skipped = <String, String>{};
  var sorted = 0;
  try {
    await server.analysis.setAnalysisRoots([projectRoot], []);
    for (var index = 0; index < files.length; index++) {
      final path = files[index];
      try {
        final result = await _sortMembers(server, path);
        if (result.edit.edits.isEmpty) continue;
        await _applyEdits(path, result.edit.edits);
        sorted++;
        stdout.writeln('sorted ${index + 1}/${files.length}: $path');
      } on RequestError catch (error) {
        skipped[path] = '${error.code}: ${error.message}';
      }
    }
  } finally {
    server.dispose();
  }

  final unchanged = files.length - sorted - skipped.length;
  stdout.writeln(
    '完成：$sorted 个文件有改动，$unchanged 个无需改动，'
    '${skipped.length} 个跳过。',
  );
  if (skipped.isNotEmpty) {
    stdout.writeln('跳过的文件：');
    skipped.forEach((path, reason) => stdout.writeln('  $path\n    $reason'));
    exitCode = 1;
  }
}

/// 上下文还没建好（FILE_NOT_ANALYZED），或批量改写触发服务器重分析、
/// 当前会话已过期（CONTENT_MODIFIED）时短暂重试。
const _retryableCodes = {'FILE_NOT_ANALYZED', 'CONTENT_MODIFIED'};

/// 不参与遍历的目录名。
const _skippedDirectories = {'.dart_tool', 'build', '.git'};

/// build_runner 等代码生成器的产物：重排后会被下一次生成覆盖，没有意义。
final _generatedFile = RegExp(r'\.(g|freezed|gr|mocks|gen)\.dart$');

/// SourceEdit 的偏移量基于 UTF-16 码元，Dart 的 String 下标正好一致；
/// 从后往前替换，避免前面的编辑让后面的偏移量失效。
Future<void> _applyEdits(String path, List<SourceEdit> edits) async {
  final file = File(path);
  var content = await file.readAsString();
  for (final edit
      in edits.toList()..sort((a, b) => b.offset.compareTo(a.offset))) {
    content = content.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
  await file.writeAsString(content);
}

/// 展开命令行传入的文件 / 目录，去重后返回可排序的 Dart 文件。
Iterable<String> _collectDartFiles(List<String> targets) sync* {
  final seen = <String>{};
  for (final target in targets) {
    switch (FileSystemEntity.typeSync(target)) {
      case FileSystemEntityType.file:
        if (_isSortable(target) && seen.add(target)) yield target;
      case FileSystemEntityType.directory:
        for (final entity in Directory(
          target,
        ).listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (_isSortable(path) && seen.add(path)) yield path;
        }
      default:
        stderr.writeln('忽略不存在的路径：$target');
    }
  }
}

bool _isSortable(String path) {
  if (!path.endsWith('.dart') || _generatedFile.hasMatch(path)) return false;
  return !path.split(Platform.pathSeparator).any(_skippedDirectories.contains);
}

Future<SortMembersResult> _sortMembers(
  AnalysisServer server,
  String path,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    try {
      return await server.edit.sortMembers(path);
    } on RequestError catch (error) {
      if (!_retryableCodes.contains(error.code) ||
          DateTime.now().isAfter(deadline)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}
