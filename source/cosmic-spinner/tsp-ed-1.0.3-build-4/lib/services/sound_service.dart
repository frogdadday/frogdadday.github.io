// ////Block One//////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/services.dart';

class SoundService {
  SoundService._();

  static const MethodChannel _channel = MethodChannel('cosmic_spinner/sound');
  static DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> kick({required bool enabled}) async {
    if (!enabled) return;
    await _invoke('kick');
  }

  static Future<void> tick({required bool enabled}) async {
    if (!enabled) return;
    final now = DateTime.now();
    if (now.difference(_lastTick) < const Duration(milliseconds: 65)) return;
    _lastTick = now;
    HapticFeedback.selectionClick();
    await _invoke('tick');
  }

  static Future<void> reveal({required bool enabled}) async {
    HapticFeedback.mediumImpact();
    if (enabled) await _invoke('reveal');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel
          .invokeMethod<void>(method)
          .timeout(const Duration(milliseconds: 250));
    } on MissingPluginException {
      if (method == 'tick') await SystemSound.play(SystemSoundType.click);
    } on PlatformException {
      // Sound is decorative; never let it interrupt the decision.
    } on TimeoutException {
      // Sound is decorative; never let it interrupt the decision.
    }
  }
}
