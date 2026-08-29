import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/views/connection/item.dart';
import 'package:flutter_test/flutter_test.dart';

Group makeGroup(String name, {String icon = ''}) =>
    Group(type: GroupType.Selector, name: name, icon: icon);

void main() {
  group('chainIcon', () {
    final groups = [
      makeGroup('YouTube', icon: 'https://cdn.example/youtube.png'),
      makeGroup('Fallback'),
    ];

    test('a group that has one is used', () {
      expect(chainIcon(groups, 'YouTube'), 'https://cdn.example/youtube.png');
    });

    test('a group without an icon yields nothing', () {
      // The chip must then render no avatar at all rather than an empty box,
      // or the labels stop lining up down the list.
      expect(chainIcon(groups, 'Fallback'), '');
    });

    test('the final node is not a group and yields nothing', () {
      // Nodes come out of a provider and never carry an icon — their flag is
      // in the name instead.
      expect(chainIcon(groups, '🇫🇮 Finland-01 | Дроид | ⏳90D'), '');
    });

    test('no groups loaded yet yields nothing', () {
      expect(chainIcon(const [], 'YouTube'), '');
    });
  });

  group('orderedChains', () {
    test('reverses so the deciding group comes before the node', () {
      // mihomo returns the chain innermost first, which reads backwards: the
      // node it ended on before the rule that sent it there.
      expect(
        orderedChains(const ['fi-01', 'Fallback', 'YouTube']),
        ['YouTube', 'Fallback', 'fi-01'],
      );
    });

    test('a single link is unchanged', () {
      expect(orderedChains(const ['DIRECT']), ['DIRECT']);
    });

    test('an empty chain stays empty', () {
      expect(orderedChains(const []), isEmpty);
    });
  });
}
