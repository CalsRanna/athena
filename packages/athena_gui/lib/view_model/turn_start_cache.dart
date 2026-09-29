import 'package:athena_core/util/logger_util.dart';
import 'package:signals/signals.dart';

/// 会话的「轮次起点」缓存：每条对话里处于轮次开头的 user 消息 id。
///
/// 轮次数是**整段会话**的属性，而消息列表只是个窗口——所以不能在列表上现推，必须
/// 整文件扫一遍并缓存。扫描可能较慢（长会话的 JSONL 可达几百 MB），因此不阻塞会话
/// 切换：扫描期间指示器不显示（计数未知时宁可空着，也不给一个错的数字），扫完由
/// 信号驱动画出来。
///
/// 三件事让它比看上去复杂，都值得写在这里：
/// - **扫描期间新落库的 user 消息先记进 [_pending]**，扫完再并入——否则扫描结果是
///   基于旧文件读出来的，会把这期间新增的那一轮盖掉；
/// - **扫描是异步的，回来时可能已经切走对话或换了加载代次**（[currentGeneration]），
///   那时只写缓存、不动信号，避免把 A 对话的轮次画到 B 上；
/// - **删消息时按 id 集合移除**，不能比较 UUID 大小。
class TurnStartCache {
  TurnStartCache({
    required String? Function() currentChatId,
    required int Function() currentGeneration,
    required Future<List<String>> Function(String chatId) scan,
  }) : _currentChatId = currentChatId,
       _currentGeneration = currentGeneration,
       _scan = scan;

  final String? Function() _currentChatId;
  final int Function() _currentGeneration;
  final Future<List<String>> Function(String chatId) _scan;

  /// 当前对话的轮次起点，供指示器直接读。非当前对话的那些存在 [_byChat] 里。
  final turnStartIds = listSignal<String>([]);

  final Map<String, List<String>> _byChat = {};

  /// 扫描还没回来时新落库的 user 消息，扫完并入（见类注释）。
  final Map<String, List<String>> _pending = {};

  /// 命中缓存就给缓存，否则先空着等扫描。
  void selectChat(String chatId) {
    turnStartIds.value = _byChat[chatId] ?? const [];
  }

  /// 新会话：轮次数已知是 0，不必等扫描，指示器从第二轮起就能画。
  void seedEmpty(String chatId) {
    _byChat[chatId] = [];
    turnStartIds.value = const [];
  }

  /// 丢掉某条对话的缓存。id 传 null 是 no-op（调用点的 chat 未必已落库）。
  void drop(String? chatId) {
    _byChat.remove(chatId);
    _pending.remove(chatId);
  }

  void dropMany(Iterable<String> chatIds) {
    for (final chatId in chatIds) {
      drop(chatId);
    }
  }

  void clear() {
    _byChat.clear();
    _pending.clear();
    turnStartIds.value = const [];
  }

  /// 删消息已持有被删的 id 集合，按身份移除轮次（不能比较 UUID 大小）。
  void prune(String chatId, Set<String> deletedIds) {
    final cached = _byChat[chatId];
    if (cached == null) return;
    final kept = cached.where((id) => !deletedIds.contains(id)).toList();
    _byChat[chatId] = kept;
    if (_currentChatId() == chatId) turnStartIds.value = kept;
  }

  /// 新落库一条 user 消息 = 会话多了一轮。
  ///
  /// 计数只认文件：扫描结果已到手就地追加，还没到手先记进 [_pending]。**不**从消息
  /// 列表里推——列表是窗口，轮次数跟加载到哪无关。
  void record(String chatId, String? messageId) {
    if (messageId == null) return;
    final cached = _byChat[chatId];
    if (cached == null) {
      final pending = _pending.putIfAbsent(chatId, () => []);
      if (!pending.contains(messageId)) pending.add(messageId);
      return;
    }
    if (cached.contains(messageId)) return;
    final updated = [...cached, messageId];
    _byChat[chatId] = updated;
    if (_currentChatId() == chatId) turnStartIds.value = updated;
  }

  /// 读一次整段会话的轮次起点并缓存。
  ///
  /// [generation] 是调用方在开始加载时抓的代次，由调用方传入而不是这里现读：
  /// 语义是「这次扫描属于哪一次加载」，调用方才是唯一知道这件事的人。
  ///
  /// 失败只记警告、不抛：装饰性的东西不该挡住会话。
  Future<void> load(String chatId, int generation) async {
    try {
      final scanned = await _scan(chatId);
      final pending = _pending.remove(chatId) ?? const <String>[];
      final ids = [
        ...scanned,
        for (final id in pending)
          if (!scanned.contains(id)) id,
      ];
      _byChat[chatId] = ids;
      // 回来时可能已经切走对话或换了加载代次：那时只写缓存、不动信号，
      // 免得把 A 的轮次画到 B 上
      if (generation != _currentGeneration() || _currentChatId() != chatId) {
        return;
      }
      turnStartIds.value = ids;
    } catch (e) {
      LoggerUtil.w('轮次起点扫描失败,指示器本次不显示', error: e);
    }
  }
}
