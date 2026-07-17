import 'dart:ui';

class ViewNode {
  final int index;
  final String text;
  final String className;
  final String package;
  final String contentDesc;
  final String resourceId;
  final int instance;
  final bool checkable;
  final bool checked;
  final bool clickable;
  final bool enabled;
  final bool focusable;
  final bool focused;
  final bool scrollable;
  final bool longClickable;
  final bool password;
  final bool selected;
  final String boundsStr;
  final List<ViewNode> children;

  ViewNode({
    required this.index,
    required this.text,
    required this.className,
    required this.package,
    required this.contentDesc,
    required this.resourceId,
    required this.instance,
    required this.checkable,
    required this.checked,
    required this.clickable,
    required this.enabled,
    required this.focusable,
    required this.focused,
    required this.scrollable,
    required this.longClickable,
    required this.password,
    required this.selected,
    required this.boundsStr,
    required this.children,
  });

  factory ViewNode.fromJson(Map<String, dynamic> json) {
    return ViewNode(
      index: (json['index'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      package: json['package']?.toString() ?? '',
      contentDesc: json['contentDesc']?.toString() ?? '',
      resourceId: json['resourceId']?.toString() ?? '',
      instance: (json['instance'] as num?)?.toInt() ?? 0,
      checkable: json['checkable'] == true,
      checked: json['checked'] == true,
      clickable: json['clickable'] == true,
      enabled: json['enabled'] != false,
      focusable: json['focusable'] == true,
      focused: json['focused'] == true,
      scrollable: json['scrollable'] == true,
      longClickable: json['longClickable'] == true,
      password: json['password'] == true,
      selected: json['selected'] == true,
      boundsStr: json['bounds']?.toString() ?? '',
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ViewNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Cached once — parseBounds used to run a fresh RegExp per rebuild.
  Rect? get bounds {
    final cached = _boundsCache;
    if (cached != null || _boundsParsed) return cached;
    _boundsParsed = true;
    _boundsCache = parseBounds(boundsStr);
    return _boundsCache;
  }

  Rect? _boundsCache;
  bool _boundsParsed = false;

  static Rect? parseBounds(String s) {
    final match = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]').firstMatch(s);
    if (match == null) return null;
    return Rect.fromLTRB(
      double.parse(match.group(1)!),
      double.parse(match.group(2)!),
      double.parse(match.group(3)!),
      double.parse(match.group(4)!),
    );
  }

  // Last segment after ':', e.g. "com.x:id/btn_ok" -> "btn_ok".
  // Empty when resource-id missing (system-only attrs).
  String get resourceEntryName {
    final id = resourceId;
    final colon = id.indexOf(':');
    return colon >= 0 ? id.substring(colon + 1) : id;
  }

  String get displayName {
    if (text.isNotEmpty) return text;
    if (contentDesc.isNotEmpty) return contentDesc;
    final rid = resourceEntryName;
    if (rid.isNotEmpty) return rid;
    return shortClass;
  }

  String get shortClass {
    final parts = className.split('.');
    return parts.last;
  }
}

/// Result of a view-hierarchy dump. `rotation` is 0/1/2/3 = the number of
/// 90° counter-clockwise turns the device is currently at. The screenshot
/// PNG comes back in its physical (pre-rotation) orientation, so the screen
/// has to rotate the displayed image by the same amount before overlaying
/// node bounds — otherwise the highlighted box sits at wrong coords in
/// landscape / CoordinatorLayout edge cases.
class HierarchyDump {
  final ViewNode root;
  final int rotation;

  const HierarchyDump(this.root, this.rotation);
}
