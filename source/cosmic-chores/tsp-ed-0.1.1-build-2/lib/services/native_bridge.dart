// /////Block One/////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/services.dart';

import '../models/chore_list.dart';

class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('cosmic_chores/native');
  static final StreamController<void> _reminderOpened =
      StreamController<void>.broadcast();
  static bool _listeningForReminderEvents = false;

  static Future<String?> readState() =>
      _channel.invokeMethod<String>('readState');

  static Future<String?> readStateBackup() =>
      _channel.invokeMethod<String>('readStateBackup');

  static Future<void> restoreStateBackup() =>
      _channel.invokeMethod<void>('restoreStateBackup');

  static Future<String?> takeReminderListId() =>
      _channel.invokeMethod<String>('takeReminderListId');

  static Future<ReminderLaunch?> takeReminder() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('takeReminder');
    final id = raw?['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final rawDate = raw?['date'] as String?;
    return ReminderLaunch(id: id, date: DateTime.tryParse(rawDate ?? ''));
  }

  static Stream<void> get reminderOpened => _reminderOpened.stream;

  static void listenForReminderEvents() {
    if (_listeningForReminderEvents) return;
    _listeningForReminderEvents = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reminderOpened') _reminderOpened.add(null);
    });
  }

  static Future<void> writeState(String json) =>
      _channel.invokeMethod<void>('writeState', json);

  // /////Block Two///////////////////////////////////////////////////////////
  static Future<bool> hasContactsPermission() async {
    return await _channel.invokeMethod<String>('contactsPermission') ==
        'granted';
  }

  static Future<bool> requestContacts() async {
    return await _channel.invokeMethod<bool>('requestContacts') ?? false;
  }

  static Future<List<ChorePerson>> searchContacts(String query) async {
    final raw = await _channel.invokeListMethod<Object?>(
      'searchContacts',
      <String, Object?>{'query': query},
    );
    return (raw ?? const <Object?>[]).map((item) {
      final map = Map<String, Object?>.from(item! as Map);
      return ChorePerson(
        name: map['name']! as String,
        phone: map['phone']! as String,
      );
    }).toList();
  }

  // /////Block Three/////////////////////////////////////////////////////////
  static Future<bool> openSupport() async {
    return await _channel.invokeMethod<bool>('openSupport') ?? false;
  }

  static Future<bool> openPrivacyPolicy() async {
    return await _channel.invokeMethod<bool>('openPrivacyPolicy') ?? false;
  }

  static Future<bool> openNotificationSettings() async {
    return await _channel.invokeMethod<bool>('openNotificationSettings') ??
        false;
  }

  static Future<bool> readCosmicMode() async {
    return await _channel.invokeMethod<bool>('readCosmicMode') ?? false;
  }

  static Future<void> writeCosmicMode(bool enabled) {
    return _channel.invokeMethod<void>('writeCosmicMode', enabled);
  }

  static Future<String?> readMissionProgress() {
    return _channel.invokeMethod<String>('readMissionProgress');
  }

  static Future<void> writeMissionProgress(String json) {
    return _channel.invokeMethod<void>('writeMissionProgress', json);
  }

  static Future<bool> shareMessage({
    required String body,
    required List<String> recipients,
  }) async {
    return await _channel.invokeMethod<bool>('shareMessage', <String, Object?>{
          'body': body,
          'recipients': recipients,
        }) ??
        false;
  }

  // /////Block Four//////////////////////////////////////////////////////////
  static Future<bool> scheduleReminder(
    ChoreList list, {
    bool requestPermission = true,
  }) async {
    return await _channel.invokeMethod<bool>(
          'scheduleReminder',
          _reminderArguments(list, requestPermission: requestPermission),
        ) ??
        false;
  }

  /// Makes a missing reminder available without replacing one Android may
  /// still be holding for today. This is deliberately used at app startup:
  /// Android's inexact alarm can arrive late, and rescheduling it after the
  /// selected time would otherwise skip that day's notification.
  static Future<bool> ensureReminder(ChoreList list) async {
    return await _channel.invokeMethod<bool>(
          'ensureReminder',
          _reminderArguments(list, requestPermission: false),
        ) ??
        false;
  }

  static Map<String, Object?> _reminderArguments(
    ChoreList list, {
    required bool requestPermission,
  }) => <String, Object?>{
    'id': list.id,
    'title': list.title,
    'requestPermission': requestPermission,
    'hour': list.sendHour,
    'minute': list.sendMinute,
    'template': list.template.name,
    'rotationMode': list.rotationMode.name,
    'rotationAnchorDate':
        '${list.rotationAnchor.year}-${list.rotationAnchor.month.toString().padLeft(2, '0')}-${list.rotationAnchor.day.toString().padLeft(2, '0')}',
    'rotationAnchorMillis': DateTime(
      list.rotationAnchor.year,
      list.rotationAnchor.month,
      list.rotationAnchor.day,
      12,
    ).millisecondsSinceEpoch,
    'messagesByRotation': List<List<String>>.generate(
      list.people.length,
      (rotationStep) => List<String>.generate(
        list.storageDayCount,
        (day) => list.messageForDay(day, rotationStep: rotationStep),
      ),
    ),
    'recipients': list.messageRecipients,
  };

  static Future<void> cancelReminder(String id) => _channel.invokeMethod<void>(
    'cancelReminder',
    <String, Object?>{'id': id},
  );
}

// /////Block Five///////////////////////////////////////////////////////////
class ReminderLaunch {
  const ReminderLaunch({required this.id, this.date});

  final String id;
  final DateTime? date;
}
