import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// 将 HTML 转换为适合 LLM 消费的 Markdown 文本。
///
/// 保留标题、链接、列表、代码块等结构信息，同时剥离无意义的
/// 样式/脚本标签和冗余空白，大幅减少 token 消耗。
String htmlToMarkdown(String html, {Uri? pageUrl}) {
  final document = html_parser.parse(html);
  final buffer = StringBuffer();
  final baseHref = document.querySelector('base[href]')?.attributes['href'];
  final declaredBase = baseHref == null ? null : Uri.tryParse(baseHref);
  final baseUrl = declaredBase == null
      ? pageUrl
      : pageUrl?.resolveUri(declaredBase) ?? declaredBase;
  _walk(document.body ?? document, buffer, _Context(baseUrl));
  return _collapseBlankLines(buffer.toString());
}

/// 遍历上下文：跟踪列表编号和嵌套深度。
class _Context {
  _Context(this.baseUrl);
  final Uri? baseUrl;
  int olCounter = 0;
  int indentLevel = 0;
}

/// 不产生可视内容的标签——跳过其本体但遍历其子节点。
const _transparentTags = {
  'html',
  'head',
  'body',
  'div',
  'span',
  'section',
  'article',
  'main',
  'aside',
  'header',
  'footer',
  'nav',
  'figure',
  'figcaption',
  'details',
  'summary',
  'dialog',
  'data',
  'time',
  'abbr',
  'bdi',
  'bdo',
  'dfn',
  'kbd',
  'mark',
  'ruby',
  'rt',
  'rp',
  'samp',
  'small',
  'sub',
  'sup',
  'template',
  'wbr',
  'noscript',
  'map',
  'area',
  'canvas',
  'svg',
  'math',
  'picture',
  'source',
  'track',
  'video',
  'audio',
  'embed',
  'object',
  'param',
  'iframe',
};

/// 完全跳过的标签（及其子节点）：脚本、样式、元数据。
const _skipTags = {'script', 'style', 'meta', 'link', 'title'};

/// 块级标签：其前后应产生换行。
const _blockTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'blockquote',
  'pre',
  'hr',
  'table',
  'tr',
  'dl',
  'dt',
  'dd',
  'fieldset',
};

void _walk(Node node, StringBuffer buffer, _Context ctx) {
  if (node is Text) {
    _writeText(buffer, node.text);
    return;
  }
  if (node is! Element) return;

  final tag = node.localName?.toLowerCase() ?? '';
  if (_skipTags.contains(tag)) return;

  final children = node.nodes;
  final href = _attr(node, 'href');
  final src = _attr(node, 'src');
  final alt = _attr(node, 'alt');

  switch (tag) {
    // ---- 标题 ----
    case 'h1':
      buffer.write('\n# ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');
    case 'h2':
      buffer.write('\n## ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');
    case 'h3':
      buffer.write('\n### ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');
    case 'h4':
      buffer.write('\n#### ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');
    case 'h5':
      buffer.write('\n##### ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');
    case 'h6':
      buffer.write('\n###### ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');

    // ---- 段落 ----
    case 'p':
      buffer.write('\n');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');

    // ---- 换行 ----
    case 'br':
      buffer.writeln();

    // ---- 分割线 ----
    case 'hr':
      buffer.writeln('\n---\n');

    // ---- 链接 ----
    case 'a':
      if (href != null && href.isNotEmpty && !href.startsWith('#')) {
        buffer.write('[');
        _walkChildren(children, buffer, ctx);
        buffer.write('](${_resolveUrl(href, ctx)})');
      } else {
        // 空链接或锚点：只保留文本
        _walkChildren(children, buffer, ctx);
      }

    // ---- 图片 ----
    case 'img':
      if (src != null && src.isNotEmpty) {
        final resolved = _resolveUrl(src, ctx);
        buffer.write('![${alt ?? ''}]($resolved)');
      }

    // ---- 强调 ----
    case 'strong':
    case 'b':
      buffer.write('**');
      _walkChildren(children, buffer, ctx);
      buffer.write('**');
    case 'em':
    case 'i':
      buffer.write('*');
      _walkChildren(children, buffer, ctx);
      buffer.write('*');
    case 'code':
      if (_isInsidePre(node)) {
        _walkChildren(children, buffer, ctx);
      } else {
        buffer.write('`');
        _walkChildren(children, buffer, ctx);
        buffer.write('`');
      }
    case 'pre':
      // HTML parser 已解码实体；代码里的缩进、空行与字面实体不能再清洗。
      final code = node.text;
      final longestFence = RegExp(r'`+')
          .allMatches(code)
          .fold<int>(
            2,
            (longest, match) => match.group(0)!.length > longest
                ? match.group(0)!.length
                : longest,
          );
      final fence = '`' * (longestFence + 1);
      buffer.writeln('\n$fence');
      buffer.write(code);
      if (!code.endsWith('\n')) buffer.writeln();
      buffer.writeln('$fence\n');
    case 'del':
    case 's':
      buffer.write('~~');
      _walkChildren(children, buffer, ctx);
      buffer.write('~~');
    case 'ins':
    case 'u':
      // Markdown 无原生下划线，保留文本。
      _walkChildren(children, buffer, ctx);

    // ---- 引用块 ----
    case 'blockquote':
      buffer.write('\n> ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln('\n');

    // ---- 列表 ----
    case 'ul':
      buffer.writeln();
      ctx.indentLevel++;
      _walkChildren(children, buffer, ctx);
      ctx.indentLevel--;
      buffer.writeln();
    case 'ol':
      buffer.writeln();
      ctx.indentLevel++;
      final saved = ctx.olCounter;
      ctx.olCounter = 0;
      _walkChildren(children, buffer, ctx);
      ctx.olCounter = saved;
      ctx.indentLevel--;
      buffer.writeln();
    case 'li':
      final indent = '  ' * (ctx.indentLevel - 1);
      final parentOl = node.parent?.localName?.toLowerCase() == 'ol';
      if (parentOl) {
        ctx.olCounter++;
        buffer.write('\n$indent${ctx.olCounter}. ');
      } else {
        buffer.write('\n$indent- ');
      }
      _walkChildren(children, buffer, ctx);

    // ---- 表格（简化为逐行文本） ----
    case 'table':
      buffer.writeln();
      _walkChildren(children, buffer, ctx);
      buffer.writeln();
    case 'thead':
    case 'tbody':
    case 'tfoot':
      _walkChildren(children, buffer, ctx);
    case 'tr':
      _walkChildren(children, buffer, ctx);
      buffer.writeln();
    case 'th':
    case 'td':
      buffer.write('| ');
      _walkChildren(children, buffer, ctx);
      buffer.write(' ');

    // ---- 描述列表 ----
    case 'dl':
      buffer.writeln();
      _walkChildren(children, buffer, ctx);
      buffer.writeln();
    case 'dt':
      buffer.write('\n**');
      _walkChildren(children, buffer, ctx);
      buffer.write('**\n');
    case 'dd':
      buffer.write('  ');
      _walkChildren(children, buffer, ctx);
      buffer.writeln();

    // ---- 透明标签 / 其他 ----
    default:
      if (_transparentTags.contains(tag)) {
        if (_blockTags.contains(tag)) {
          buffer.writeln();
          _walkChildren(children, buffer, ctx);
          buffer.writeln();
        } else {
          _walkChildren(children, buffer, ctx);
        }
      } else {
        // 未知标签：只遍历子节点
        _walkChildren(children, buffer, ctx);
      }
  }
}

void _walkChildren(List<Node> children, StringBuffer buffer, _Context ctx) {
  for (final child in children) {
    _walk(child, buffer, ctx);
  }
}

/// 普通文本只折叠空白，不丢节点边界上的词间空格。
void _writeText(StringBuffer buffer, String text) {
  buffer.write(text.replaceAll('\u200B', '').replaceAll(RegExp(r'\s+'), ' '));
}

/// 判断 [node] 是否在 <pre> 内部。
bool _isInsidePre(Node node) {
  Element? parent = node.parent;
  while (parent != null) {
    if (parent.localName?.toLowerCase() == 'pre') return true;
    parent = parent.parent;
  }
  return false;
}

/// 合并连续空行，最多保留一个空行。
String _collapseBlankLines(String text) {
  final lines = <String>[];
  String? fence;
  var blankLines = 0;
  for (final line in text.split('\n')) {
    final marker = RegExp(r'^`{3,}$').hasMatch(line) ? line : null;
    if (fence != null) {
      lines.add(line);
      if (marker == fence) fence = null;
      continue;
    }
    if (marker != null) fence = marker;
    if (line.trim().isEmpty) {
      if (++blankLines <= 1) lines.add('');
    } else {
      blankLines = 0;
      lines.add(line);
    }
  }
  return lines.join('\n').trim();
}

/// 提取属性值（不区分大小写）。
String? _attr(Element element, String name) {
  final v = element.attributes[name];
  if (v != null) return v;
  // 不区分大小写匹配
  for (final key in element.attributes.keys) {
    if (key is String && key.toLowerCase() == name) {
      return element.attributes[key];
    }
  }
  return null;
}

/// 相对链接与图片使用文档的 base 或最终页面 URL。
String _resolveUrl(String value, _Context ctx) {
  final uri = Uri.tryParse(value);
  if (uri == null || ctx.baseUrl == null) return value;
  return ctx.baseUrl!.resolveUri(uri).toString();
}
