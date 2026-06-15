import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';

enum TouchAction {
  moveJoystick,
  jump,
  sneak,
  sprint,
  attack,
  useItem,
  inventory,
  chat,
  pause,
}

class TouchButtonConfig {
  final TouchAction action;
  double x;     // 0..1 of screen width  (normalized so it survives rotation)
  double y;     // 0..1 of screen height
  double size;  // 0..1 of screen min-dim
  double opacity;

  TouchButtonConfig({
    required this.action,
    required this.x,
    required this.y,
    this.size = 0.12,
    this.opacity = 0.55,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'x': x,
        'y': y,
        'size': size,
        'opacity': opacity,
      };

  factory TouchButtonConfig.fromJson(Map<String, dynamic> json) =>
      TouchButtonConfig(
        action: TouchAction.values.firstWhere((a) => a.name == json['action']),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        size: (json['size'] as num?)?.toDouble() ?? 0.12,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.55,
      );
}

/// Persists touch overlay layouts per profile. Sending actual input events
/// into the running game process is **not yet implemented** — that requires
/// hooking LWJGL's input loop via JNI on Android (see ROADMAP.md). The
/// editor and config storage work today, so users can lay out their HUD
/// ahead of time.
class TouchControlsService {
  File _file(String profileId) => File(p.join(
      LauncherPaths.instance.profileDir(profileId).path,
      'touch_controls.json'));

  Future<List<TouchButtonConfig>> load(String profileId) async {
    final f = _file(profileId);
    if (!await f.exists()) return _defaultLayout();
    final raw = await f.readAsString();
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(TouchButtonConfig.fromJson)
        .toList();
  }

  Future<void> save(String profileId, List<TouchButtonConfig> buttons) async {
    final f = _file(profileId);
    await f.parent.create(recursive: true);
    await f
        .writeAsString(jsonEncode(buttons.map((b) => b.toJson()).toList()));
  }

  List<TouchButtonConfig> _defaultLayout() => [
        TouchButtonConfig(action: TouchAction.moveJoystick, x: 0.18, y: 0.78, size: 0.22),
        TouchButtonConfig(action: TouchAction.jump,        x: 0.86, y: 0.78),
        TouchButtonConfig(action: TouchAction.sneak,       x: 0.86, y: 0.92),
        TouchButtonConfig(action: TouchAction.sprint,      x: 0.18, y: 0.55),
        TouchButtonConfig(action: TouchAction.attack,      x: 0.72, y: 0.55),
        TouchButtonConfig(action: TouchAction.useItem,     x: 0.86, y: 0.55),
        TouchButtonConfig(action: TouchAction.inventory,   x: 0.94, y: 0.20, size: 0.08),
        TouchButtonConfig(action: TouchAction.chat,        x: 0.50, y: 0.06, size: 0.08),
        TouchButtonConfig(action: TouchAction.pause,       x: 0.94, y: 0.06, size: 0.08),
      ];
}
