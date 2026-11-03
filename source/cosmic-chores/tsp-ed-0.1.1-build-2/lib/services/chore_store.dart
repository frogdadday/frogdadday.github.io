// /////Block One/////////////////////////////////////////////////////////////
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/chore_list.dart';
import 'native_bridge.dart';

class ChoreStore extends ChangeNotifier {
  List<ChoreList> _lists = <ChoreList>[];
  bool _loaded = false;
  bool _disposed = false;
  String? loadError;
  Object? lastLoadFailure;
  StackTrace? lastLoadStackTrace;
  Future<void> _writes = Future<void>.value();

  List<ChoreList> get lists => List<ChoreList>.unmodifiable(_lists);
  List<ChoreList> get mainPlans =>
      List<ChoreList>.unmodifiable(_lists.where((list) => list.isMainPlan));
  List<ChoreList> linkedProjectsFor(String mainPlanId) =>
      List<ChoreList>.unmodifiable(
        _lists.where(
          (list) => list.isSpecialProject && list.addToListId == mainPlanId,
        ),
      );
  bool get loaded => _loaded;
  bool get writable => _loaded && loadError == null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<ChoreList> _parseState(String? raw) {
    final decoded = raw == null || raw.isEmpty ? <Object?>[] : jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved chore lists must be a JSON array');
    }
    final parsed = decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Saved chore list is not an object');
      }
      return ChoreList.fromJson(Map<String, Object?>.from(item));
    }).toList();
    if (parsed.map((list) => list.id).toSet().length != parsed.length) {
      throw const FormatException('Duplicate list identifiers');
    }
    return parsed;
  }

  /// Startup must not replace an already-pending reminder. Android may hold
  /// an inexact alarm briefly after its chosen time; replacing it at that
  /// moment silently turns today's reminder into tomorrow's.
  Future<void> _ensureMainPlanReminders() async {
    for (final list in _lists.where((list) => list.isMainPlan)) {
      try {
        if (list.remindersEnabled) {
          await NativeBridge.ensureReminder(list);
        } else {
          await NativeBridge.cancelReminder(list.id);
        }
      } catch (_) {
        // Lists remain usable when Android reminders are unavailable.
      }
    }
  }

  /// A restored backup intentionally becomes the new source of truth, so its
  /// reminder payloads must replace any payloads belonging to newer data.
  Future<void> _rescheduleMainPlans() async {
    for (final list in _lists.where((list) => list.isMainPlan)) {
      try {
        if (list.remindersEnabled) {
          await NativeBridge.scheduleReminder(list, requestPermission: false);
        } else {
          await NativeBridge.cancelReminder(list.id);
        }
      } catch (_) {
        // Lists remain usable when Android reminders are unavailable.
      }
    }
  }

  Future<void> load() async {
    try {
      final raw = await NativeBridge.readState();
      _lists = _parseState(raw);
      loadError = null;
      lastLoadFailure = null;
      lastLoadStackTrace = null;
      await _ensureMainPlanReminders();
    } catch (error, stackTrace) {
      lastLoadFailure = error;
      lastLoadStackTrace = stackTrace;
      loadError = 'Saved lists could not be read. Your stored data has not been changed. Retry before saving or deleting.';
    } finally {
      // This is the only startup notification. It prevents a successful load
      // from visibly rebuilding the home screen twice.
      _loaded = true;
      _notify();
    }
  }

  Future<void> restoreBackup() async {
    final raw = await NativeBridge.readStateBackup();
    final restored = _parseState(raw);
    await NativeBridge.restoreStateBackup();
    _lists = restored;
    loadError = null;
    lastLoadFailure = null;
    lastLoadStackTrace = null;
    _loaded = true;
    _notify();
    await _rescheduleMainPlans();
  }

  // /////Block Two///////////////////////////////////////////////////////////
  Future<void> save(ChoreList list) async {
    await _transaction((next) {
      final index = next.indexWhere((item) => item.id == list.id);
      if (index == -1) {
        next.add(list);
      } else {
        next[index] = list;
      }
    });
  }

  Future<void> remove(
    String id, {
    String? moveProjectsTo,
    bool deleteProjects = false,
  }) async {
    final linkedProjects = linkedProjectsFor(id);
    if (linkedProjects.isNotEmpty &&
        !deleteProjects &&
        moveProjectsTo == null) {
      throw StateError('Move or delete linked special projects first');
    }
    if (moveProjectsTo != null &&
        !mainPlans.any((list) => list.id == moveProjectsTo)) {
      throw StateError('Choose a valid weekly or work-week plan');
    }
    await _transaction((next) {
      for (var index = 0; index < next.length; index++) {
        if (next[index].addToListId == id) {
          if (next[index].isSpecialProject) {
            if (deleteProjects) continue;
            next[index] = next[index].withAddToListId(moveProjectsTo);
          } else {
            next[index] = next[index].withAddToListId(null);
          }
        }
      }
      if (deleteProjects) {
        next.removeWhere(
          (item) => item.isSpecialProject && item.addToListId == id,
        );
      }
      next.removeWhere((item) => item.id == id);
    });
    // The receiver independently checks that the list still exists.
    try {
      await NativeBridge.cancelReminder(id);
    } catch (_) {}
    for (final project in linkedProjects) {
      try {
        await NativeBridge.cancelReminder(project.id);
      } catch (_) {}
    }
    for (final list in _lists.where(
      (item) => item.isMainPlan && item.remindersEnabled,
    )) {
      try {
        await NativeBridge.scheduleReminder(list, requestPermission: false);
      } catch (_) {}
    }
  }

  Future<void> _transaction(void Function(List<ChoreList>) change) {
    final operation = _writes.then((_) async {
      if (!writable) throw StateError('Saved data is not safely loaded');
      final next = List<ChoreList>.from(_lists);
      change(next);
      await NativeBridge.writeState(
        jsonEncode(next.map((list) => list.toJson()).toList()),
      );
      _lists = next;
      _notify();
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
