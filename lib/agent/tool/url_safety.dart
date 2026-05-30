import 'dart:io';

/// 主机分类：用于 web_fetch 的 SSRF 防护。
/// 不做 DNS 解析，仅按字面 IP 段或 `localhost` 主机名判断。
enum UrlHostClass { public, loopback, linkLocal, privateLan }

/// 按字面 IP 段或 `localhost` 主机名对 [url] 的 host 分类。
/// 无法解析 / host 为空 / 普通域名 / 公网 IP 均视为 [UrlHostClass.public]。
///
/// 仅识别点分十进制 IPv4 与标准 IPv6 字面量（含 IPv4 映射形式
/// `::ffff:a.b.c.d`）。混淆的整数/十六进制写法（如 `http://2130706433/`）
/// 会被 [Uri] 解析为 null host 而归为 public —— Dart http 客户端同样不会
/// 将其当作 IPv4 解析。
UrlHostClass classifyUrlHost(String url) {
  final host = Uri.tryParse(url)?.host;
  if (host == null || host.isEmpty) return UrlHostClass.public;

  // 主机名 localhost（以及 *.localhost）视为回环。
  final lower = host.toLowerCase();
  if (lower == 'localhost' || lower.endsWith('.localhost')) {
    return UrlHostClass.loopback;
  }

  final addr = InternetAddress.tryParse(host);
  if (addr == null) return UrlHostClass.public;
  final bytes = addr.rawAddress;

  // 先判定链路本地与回环，避免被私有网段误判。
  if (addr.type == InternetAddressType.IPv4) {
    return _classifyIPv4(bytes);
  }

  if (addr.type == InternetAddressType.IPv6) {
    // IPv4 映射地址 ::ffff:a.b.c.d（前 10 字节为 0，第 11/12 字节为 0xff）：
    // 必须在 fe80/::1 判定之前用内嵌 IPv4 复判，否则可绕过链路本地硬拦。
    var mappedPrefix = true;
    for (var i = 0; i < 10; i++) {
      if (bytes[i] != 0) {
        mappedPrefix = false;
        break;
      }
    }
    if (mappedPrefix && bytes[10] == 0xff && bytes[11] == 0xff) {
      return _classifyIPv4(bytes.sublist(12, 16));
    }
    // 链路本地：fe80::/10
    if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) {
      return UrlHostClass.linkLocal;
    }
    // 回环：::1（前 15 字节为 0，末字节为 1）
    var allZero = true;
    for (var i = 0; i < 15; i++) {
      if (bytes[i] != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero && bytes[15] == 1) return UrlHostClass.loopback;
    // 唯一本地地址（ULA）fc00::/7：IPv6 的私有网段，warn-but-allow（不可达云元数据）。
    if ((bytes[0] & 0xfe) == 0xfc) return UrlHostClass.privateLan;
    return UrlHostClass.public;
  }

  return UrlHostClass.public;
}

/// 按 IPv4 字节段（4 字节）分类。供原生 IPv4 与 IPv4 映射 IPv6 共用。
UrlHostClass _classifyIPv4(List<int> b) {
  // 链路本地：169.254.0.0/16
  if (b[0] == 169 && b[1] == 254) return UrlHostClass.linkLocal;
  // 回环：127.0.0.0/8
  if (b[0] == 127) return UrlHostClass.loopback;
  // 私有网段
  if (b[0] == 10) return UrlHostClass.privateLan; // 10.0.0.0/8
  if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) {
    return UrlHostClass.privateLan; // 172.16.0.0/12
  }
  if (b[0] == 192 && b[1] == 168) {
    return UrlHostClass.privateLan; // 192.168.0.0/16
  }
  return UrlHostClass.public;
}

/// URL 是否指向非公网（内网/本地）主机。
bool isInternalUrl(String url) => classifyUrlHost(url) != UrlHostClass.public;

/// 审批弹窗使用的红色警告文案；URL 为公网（无需警告）时返回 null。
String? webFetchApprovalWarning(String? url) {
  if (url == null) return null;
  switch (classifyUrlHost(url)) {
    case UrlHostClass.linkLocal:
      return '⚠ 链路本地/云元数据地址（169.254.x.x / fe80::）：常被用于窃取云凭据，本次请求将被拒绝';
    case UrlHostClass.loopback:
      return '⚠ 本地回环地址（localhost / 127.x）：可能用于探测本机服务';
    case UrlHostClass.privateLan:
      return '⚠ 内网地址（私有网段）：可能用于探测内网服务';
    case UrlHostClass.public:
      return null;
  }
}
