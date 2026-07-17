// Unit tests for the ViewNode helpers added for the view-hierarchy
// reverse-select, filter / search, and node-action features.

import 'package:adb_tool/models/view_node.dart';
import 'package:flutter_test/flutter_test.dart';

ViewNode _node({
  required String cls,
  String bounds = '',
  String resourceId = '',
  String text = '',
  String contentDesc = '',
  bool clickable = false,
  List<ViewNode> children = const [],
  int index = 0,
}) {
  return ViewNode(
    index: index,
    text: text,
    className: cls,
    package: '',
    contentDesc: contentDesc,
    resourceId: resourceId,
    instance: 0,
    checkable: false,
    checked: false,
    clickable: clickable,
    enabled: true,
    focusable: false,
    focused: false,
    scrollable: false,
    longClickable: false,
    password: false,
    selected: false,
    boundsStr: bounds,
    children: children,
  );
}

void main() {
  group('ViewNode.matchesQuery', () {
    test('empty query matches everything', () {
      final n = _node(cls: 'android.widget.TextView');
      expect(n.matchesQuery(''), isTrue);
    });

    test('matches by className (case-insensitive)', () {
      final n = _node(cls: 'android.widget.TextView');
      expect(n.matchesQuery('textview'), isTrue);
      expect(n.matchesQuery('TEXT'), isTrue);
    });

    test('matches by resource id', () {
      final n = _node(cls: 'View', resourceId: 'com.example:id/login_btn');
      expect(n.matchesQuery('login_btn'), isTrue);
      expect(n.matchesQuery('example'), isTrue);
    });

    test('matches by content-desc when other fields are empty', () {
      final n = _node(cls: 'View', contentDesc: 'settings gear');
      expect(n.matchesQuery('gear'), isTrue);
    });

    test('does not match unrelated query', () {
      final n = _node(cls: 'View', text: 'Login');
      expect(n.matchesQuery('xyz'), isFalse);
    });
  });

  group('ViewNode.hitTest', () {
    final tree = _node(
      cls: 'Root',
      bounds: '[0,0][1000,2000]',
      children: [
        _node(
          cls: 'Container',
          bounds: '[0,0][1000,500]',
          clickable: true,
          children: [
            _node(
              cls: 'DeepBtn',
              bounds: '[400,200][600,300]',
              clickable: true,
            ),
          ],
        ),
        _node(
          cls: 'InertBg',
          bounds: '[0,500][1000,2000]',
          // huge area, not clickable — should never be chosen when a
          // smaller clickable exists inside its region.
        ),
      ],
    );

    test('prefers smaller clickable area over enclosing inert node', () {
      final hit = ViewNode.hitTest(
          tree, const Offset(450, 250))!;
      expect(hit.className, 'DeepBtn');
    });

    test('falls back to smallest containing node when none clickable in region',
        () {
      final hit = ViewNode.hitTest(tree, const Offset(100, 100))!;
      expect(hit.className, 'Container');
    });

    test('returns null outside root bounds', () {
      final hit = ViewNode.hitTest(tree, const Offset(-10, 100));
      expect(hit, isNull);
    });
  });

  group('ViewNode.ancestorChain', () {
    final leaf = _node(cls: 'Leaf');
    final mid = _node(cls: 'Mid', children: [leaf]);
    final root = _node(cls: 'Root', children: [mid]);

    test('returns chain from root to target', () {
      final chain = ViewNode.ancestorChain(root, leaf)!;
      expect(chain.map((n) => n.className), ['Root', 'Mid', 'Leaf']);
    });

    test('returns single-element chain when target is root itself', () {
      final chain = ViewNode.ancestorChain(root, root)!;
      expect(chain.length, 1);
      expect(chain.single.className, 'Root');
    });

    test('returns null when target not in tree', () {
      final other = _node(cls: 'Other');
      expect(ViewNode.ancestorChain(root, other), isNull);
    });
  });

  group('ViewNode.toXPath', () {
    test('uses resource-id when present', () {
      final n = _node(
        cls: 'Button',
        resourceId: 'com.example:id/login',
        bounds: '[10,20][30,40]',
      );
      expect(n.toXPath(),
          '//node[@resource-id="com.example:id/login" and @bounds="[10,20][30,40]"]');
    });

    test('falls back to class when resource-id missing', () {
      final n = _node(cls: 'android.widget.TextView', bounds: '[0,0][1,1]');
      expect(n.toXPath(),
          '//node[@class="android.widget.TextView" and @bounds="[0,0][1,1]"]');
    });

    test('escapes embedded double quotes in resource-id', () {
      final n = _node(
        cls: 'View',
        resourceId: 'weird"id',
        bounds: '[0,0][1,1]',
      );
      expect(n.toXPath(), contains('weird"id'.replaceAll('"', '\\"')));
    });
  });
}