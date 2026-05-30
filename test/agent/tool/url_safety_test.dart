import 'package:athena/agent/tool/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyUrlHost link-local', () {
    test('IPv4 169.254.169.254 (cloud metadata)', () {
      expect(classifyUrlHost('http://169.254.169.254/'),
          UrlHostClass.linkLocal);
    });
    test('IPv4 169.254.0.1', () {
      expect(classifyUrlHost('http://169.254.0.1/'), UrlHostClass.linkLocal);
    });
    test('IPv6 fe80::1', () {
      expect(classifyUrlHost('http://[fe80::1]/'), UrlHostClass.linkLocal);
    });
    test('IPv4-mapped IPv6 ::ffff:169.254.169.254', () {
      expect(classifyUrlHost('http://[::ffff:169.254.169.254]/'),
          UrlHostClass.linkLocal);
    });
    test('IPv4-mapped IPv6 hex form ::ffff:a9fe:a9fe', () {
      expect(classifyUrlHost('http://[::ffff:a9fe:a9fe]/'),
          UrlHostClass.linkLocal);
    });
  });

  group('classifyUrlHost loopback', () {
    test('IPv4 127.0.0.1', () {
      expect(classifyUrlHost('http://127.0.0.1/'), UrlHostClass.loopback);
    });
    test('IPv4 127.1.2.3', () {
      expect(classifyUrlHost('http://127.1.2.3/'), UrlHostClass.loopback);
    });
    test('hostname localhost', () {
      expect(classifyUrlHost('http://localhost/'), UrlHostClass.loopback);
    });
    test('hostname localhost with port', () {
      expect(classifyUrlHost('http://localhost:3000/'), UrlHostClass.loopback);
    });
    test('*.localhost', () {
      expect(classifyUrlHost('http://api.localhost/'), UrlHostClass.loopback);
    });
    test('IPv6 ::1', () {
      expect(classifyUrlHost('http://[::1]/'), UrlHostClass.loopback);
    });
    test('IPv4-mapped IPv6 ::ffff:127.0.0.1', () {
      expect(classifyUrlHost('http://[::ffff:127.0.0.1]/'),
          UrlHostClass.loopback);
    });
  });

  group('classifyUrlHost private LAN', () {
    test('10.0.0.1', () {
      expect(classifyUrlHost('http://10.0.0.1/'), UrlHostClass.privateLan);
    });
    test('192.168.1.1', () {
      expect(classifyUrlHost('http://192.168.1.1/'), UrlHostClass.privateLan);
    });
    test('172.16.0.1', () {
      expect(classifyUrlHost('http://172.16.0.1/'), UrlHostClass.privateLan);
    });
    test('172.31.255.255', () {
      expect(
          classifyUrlHost('http://172.31.255.255/'), UrlHostClass.privateLan);
    });
    test('IPv6 ULA fc00::1', () {
      expect(classifyUrlHost('http://[fc00::1]/'), UrlHostClass.privateLan);
    });
    test('IPv6 ULA fd00::1', () {
      expect(classifyUrlHost('http://[fd00::1]/'), UrlHostClass.privateLan);
    });
  });

  group('classifyUrlHost public (boundary checks)', () {
    test('public IP 8.8.8.8', () {
      expect(classifyUrlHost('http://8.8.8.8/'), UrlHostClass.public);
    });
    test('public hostname example.com', () {
      expect(classifyUrlHost('https://example.com/'), UrlHostClass.public);
    });
    test('172.15.0.1 just below the private 172.16 range', () {
      expect(classifyUrlHost('http://172.15.0.1/'), UrlHostClass.public);
    });
    test('172.32.0.1 just above the private 172.31 range', () {
      expect(classifyUrlHost('http://172.32.0.1/'), UrlHostClass.public);
    });
    test('11.0.0.1 just outside the 10.x range', () {
      expect(classifyUrlHost('http://11.0.0.1/'), UrlHostClass.public);
    });
    test('192.169.0.1 just outside 192.168', () {
      expect(classifyUrlHost('http://192.169.0.1/'), UrlHostClass.public);
    });
    test('unparseable / no host', () {
      expect(classifyUrlHost('not a url'), UrlHostClass.public);
      expect(classifyUrlHost(''), UrlHostClass.public);
    });
  });

  group('isInternalUrl', () {
    test('internal classes are internal', () {
      expect(isInternalUrl('http://169.254.169.254/'), isTrue);
      expect(isInternalUrl('http://127.0.0.1/'), isTrue);
      expect(isInternalUrl('http://localhost/'), isTrue);
      expect(isInternalUrl('http://10.0.0.1/'), isTrue);
    });
    test('public is not internal', () {
      expect(isInternalUrl('https://example.com/'), isFalse);
      expect(isInternalUrl('http://8.8.8.8/'), isFalse);
    });
  });

  group('webFetchApprovalWarning', () {
    test('null for public URLs', () {
      expect(webFetchApprovalWarning('https://example.com/'), isNull);
      expect(webFetchApprovalWarning('http://8.8.8.8/'), isNull);
      expect(webFetchApprovalWarning(null), isNull);
    });
    test('non-null for each internal class', () {
      expect(webFetchApprovalWarning('http://169.254.169.254/'), isNotNull);
      expect(webFetchApprovalWarning('http://127.0.0.1/'), isNotNull);
      expect(webFetchApprovalWarning('http://localhost/'), isNotNull);
      expect(webFetchApprovalWarning('http://10.0.0.1/'), isNotNull);
    });
  });
}
