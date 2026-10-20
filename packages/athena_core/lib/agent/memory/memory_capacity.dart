import 'package:athena_core/entity/experience_entity.dart';

/// 记忆目录的容量预算。
///
/// 目录每次 run 全量注入，是唯一会随使用时长单调增长、又没有天然上限的
/// 上下文块。没有上限时，长期使用后它会先挤占压缩的尾部队列
/// （`ConversationCompactor` 用目录估算去扣 tailBudget），再把 compaction
/// 逼到「无法降低上下文」的失败分支。
///
/// 预算按**字符**而非 token：目录渲染是纯函数、拿不到 provider 的
/// tokenizer，而本仓库的字节级估算对 provider 口径系统性偏高（见
/// `ContextBudget`）。字符预算是可预测、可测试的代理量；真正的 token
/// 余量仍由 `ContextBudget` 在每次请求前兜底。
///
/// 容量治理分两道：
/// - 写入端（`experience_learn` 的 create）在超限时拒绝写入，要求先归档或
///   合并——遗忘是显式决策，不是静默丢弃；
/// - 注入端只做安全网，用于升级前就已超限的历史数据与手工塞进目录的文件。
abstract final class MemoryCapacity {
  /// 注入目录的字符上限。
  ///
  /// lesson 上限 500 字符，一行渲染后约 550 字符，因此 16000 约合 29 条
  /// 满长经验；中文按每字符约 1 个 token 计，约占上下文 16k token，对
  /// 32k 窗口的模型也留得住对话空间。
  static const int maxCatalogChars = 16000;

  /// UUIDv7 的固定文本长度。
  ///
  /// 新经验的 id 由仓库在 save 时生成，写入前的预算检查只能用等宽占位符。
  /// 长度固定，所以这条预留是精确的而不是近似。
  static const int _idWidth = 36;

  /// 一条已存在的经验在目录里渲染成的单行（不含换行）。
  ///
  /// 写入端的预算检查与注入端的渲染共用这一个函数——两处各写一份格式，
  /// 迟早在「检查说没超，注入却截断」上漂移。
  static String renderEntry(ExperienceEntity entity) => _line(
    id: entity.id,
    shared: entity.scope == 'shared',
    date: _formatDate(entity.createdAt),
    lesson: entity.lesson,
  );

  /// 一条**尚未写入**的经验将占用的目录字符数。
  ///
  /// 日期与 id 都是定宽，因此结果与实际写入后逐字节等长。
  static int pendingEntryChars({required String lesson, required bool shared}) {
    final placeholder = _line(
      id: 'x' * _idWidth,
      shared: shared,
      date: _formatDate(DateTime(2000)),
      lesson: lesson,
    );
    return placeholder.length + 1;
  }

  /// 当前集合渲染成目录后的字符数（不含开头说明与截断提示）。
  static int catalogChars(Iterable<ExperienceEntity> experiences) =>
      experiences.fold(0, (sum, e) => sum + renderEntry(e).length + 1);

  /// [existing] 再加一条 [lesson] 是否会超出预算。
  ///
  /// 判据是「当前集合 + 新条目」：只要目录已经装满，写入就该被拦下来，
  /// 让模型先做取舍，而不是让注入端替它挑一条丢掉。
  static bool exceedsCapacity({
    required Iterable<ExperienceEntity> existing,
    required String lesson,
    required bool shared,
  }) =>
      catalogChars(existing) +
          pendingEntryChars(lesson: lesson, shared: shared) >
      maxCatalogChars;

  /// 取预算内的前缀，返回保留项与被丢弃的条数。
  ///
  /// 调用方必须按**保留优先级**排好序（最近的在前）。只在注入端使用，
  /// 正常情况下不会丢弃任何条目。
  static ({List<ExperienceEntity> kept, int dropped}) withinBudget(
    List<ExperienceEntity> sortedByPriority,
  ) {
    var chars = 0;
    for (var i = 0; i < sortedByPriority.length; i++) {
      chars += renderEntry(sortedByPriority[i]).length + 1;
      if (chars > maxCatalogChars) {
        return (
          kept: sortedByPriority.sublist(0, i),
          dropped: sortedByPriority.length - i,
        );
      }
    }
    return (kept: sortedByPriority, dropped: 0);
  }

  static String _line({
    required String id,
    required bool shared,
    required String date,
    required String lesson,
  }) {
    final origin = shared ? '共享' : '私有';
    // 换行压成空格：一条经验必须只占一行，否则「一条一行」的目录排版失效，
    // 用户与模型都无法按行数判断记忆规模。
    final text = lesson.replaceAll(RegExp(r'\s+'), ' ').trim();
    return '- [$id] ($origin, $date) $text';
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
