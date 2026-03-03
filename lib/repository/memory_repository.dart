import 'dart:convert';
import 'dart:io';

import 'package:athena/entity/memory_entity.dart';

class MemoryRepository {
  String get _basePath {
    var home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return '$home/.athena';
  }

  String get _memoryPath => '$_basePath/MEMORY.md';
  String get _metaPath => '$_basePath/memory_meta.json';

  Future<MemoryEntity?> getMemory() async {
    var memoryFile = File(_memoryPath);
    var metaFile = File(_metaPath);
    if (!await memoryFile.exists() || !await metaFile.exists()) return null;
    var content = await memoryFile.readAsString();
    var metaString = await metaFile.readAsString();
    var meta = jsonDecode(metaString) as Map<String, dynamic>;
    meta['content'] = content;
    return MemoryEntity.fromJson(meta);
  }

  Future<void> saveMemory(MemoryEntity memory) async {
    var dir = Directory(_basePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await File(_memoryPath).writeAsString(memory.content);
    await File(_metaPath).writeAsString(jsonEncode(memory.toJson()));
  }

  Future<void> deleteMemory() async {
    var memoryFile = File(_memoryPath);
    var metaFile = File(_metaPath);
    if (await memoryFile.exists()) await memoryFile.delete();
    if (await metaFile.exists()) await metaFile.delete();
  }
}
