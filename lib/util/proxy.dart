class ProxyConfig {
  static ProxyConfig instance = ProxyConfig._internal();

  String _key = '';

  String _url = '';
  final _officialKey = 'OPENAI_API_KEY';

  final _officialUrl = 'https://api.openai.com/v1';
  ProxyConfig._internal();

  String get key => _key;
  set key(String key) => _key = key.isNotEmpty ? key : _officialKey;

  String get url => _url;
  set url(String url) => _url = url.isNotEmpty ? url : _officialUrl;
}
