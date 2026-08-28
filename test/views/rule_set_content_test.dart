import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/views/proxies/rule_set_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterRuleLines', () {
    const lines = [
      'DOMAIN-SUFFIX,vk.com',
      '+.vk.com',
      'vk.com',
      'notvk.company',
      'example.org',
    ];

    test('an empty query keeps everything', () {
      expect(filterRuleLines(lines, '   '), lines);
    });

    test('matches a substring anywhere in the line', () {
      // A set stores the same host as 'DOMAIN-SUFFIX,vk.com', '+.vk.com' and a
      // bare host. Anchoring the match would miss most of them.
      expect(filterRuleLines(lines, 'vk.com'), [
        'DOMAIN-SUFFIX,vk.com',
        '+.vk.com',
        'vk.com',
        'notvk.company',
      ]);
    });

    test('ignores case on both sides', () {
      expect(filterRuleLines(const ['+.Example.ORG'], 'example.org'), [
        '+.Example.ORG',
      ]);
    });

    test('an absent needle matches nothing', () {
      expect(filterRuleLines(lines, 'zzz'), isEmpty);
    });
  });

  group('RuleSetContent', () {
    test('reads a truncated window and keeps the real total', () {
      // The core caps what it returns; the count has to stay honest or
      // "showing N of M" would silently mean "at least".
      final content = RuleSetContent.fromJson(const {
        'lines': ['a.com', 'b.com'],
        'total': 240000,
        'truncated': true,
      });

      expect(content.lines.length, 2);
      expect(content.total, 240000);
      expect(content.truncated, isTrue);
      expect(content.error, isEmpty);
    });

    test('carries an error with no lines', () {
      final content = RuleSetContent.fromJson(const {
        'lines': <String>[],
        'total': 0,
        'truncated': false,
        'error': 'provider is not a rule set',
      });

      expect(content.lines, isEmpty);
      expect(content.error, 'provider is not a rule set');
    });
  });
}
