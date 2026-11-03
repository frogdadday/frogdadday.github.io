import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/spinner_model.dart';

class AppController extends ChangeNotifier {
  AppController() {
    ready = _load();
  }
  static const MethodChannel _channel = MethodChannel('cosmic_spinner/storage');
  late Future<void> ready;
  final List<SpinnerModel> _saved = [];
  final List<Object?> _unreadable = [];
  Object? _unreadableDraft;
  SpinnerModel? _draft;
  SpinnerModel? _previouslyStoredDraft;
  bool _localSavingAllowed = false;
  bool get localSavingAllowed => _localSavingAllowed;
  bool _soundOn = true, _cosmicMode = false, _disposed = false;
  bool loading = true, loaded = false, saving = false;
  String? loadError, saveError, recoveryWarning;
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  List<SpinnerModel> get saved => List.unmodifiable(
    List<SpinnerModel>.from(_saved)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
  );
  SpinnerModel? get draft => _draft;
  bool get soundOn => _soundOn;
  bool get cosmicMode => _cosmicMode;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> retryLoad() async {
    if (loading || loaded) return;
    ready = _load();
    await ready;
  }

  Future<void> _load() async {
    loading = true;
    loadError = null;
    _notify();
    try {
      final raw = await _channel
          .invokeMethod<String>('read')
          .timeout(const Duration(seconds: 10));
      final data = raw == null
          ? <String, Object?>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != null && data['version'] != 1) {
        throw const FormatException('Unsupported storage version');
      }
      final entries = data['saved'] ?? <Object?>[];
      if (entries is! List) throw const FormatException('Invalid saved list');
      final recovered = <SpinnerModel>[];
      _unreadable.clear();
      final ids = <String>{};
      for (final entry in entries) {
        try {
          final model = SpinnerModel.fromJson(
            Map<String, Object?>.from(entry as Map),
          );
          if (!ids.add(model.id)) throw const FormatException('Duplicate id');
          recovered.add(model);
        } catch (_) {
          _unreadable.add(entry);
        }
      }
      _draft = null;
      _unreadableDraft = data['unreadableDraft'];
      if (data['draft'] != null) {
        try {
          _draft = SpinnerModel.fromJson(
            Map<String, Object?>.from(data['draft'] as Map),
          );
        } catch (_) {
          _unreadableDraft = data['draft'];
        }
      }
      _saved
        ..clear()
        ..addAll(recovered);
      _previouslyStoredDraft = _draft;
      _localSavingAllowed = data['localSavingAllowed'] == true;
      _soundOn = data['soundOn'] is bool ? data['soundOn'] as bool : true;
      _cosmicMode = data['cosmicMode'] is bool
          ? data['cosmicMode'] as bool
          : false;
      recoveryWarning = _unreadable.isNotEmpty || _unreadableDraft != null
          ? 'Some saved data could not be opened. Recoverable wheels are available; damaged records have been preserved.'
          : null;
      loaded = true;
    } catch (_) {
      loadError = 'Your saved spinners could not be loaded. Please retry. Existing data has not been replaced.';
    } finally {
      loading = false;
      _notify();
    }
  }

  // Mutations wait for startup; writes are serialized so older state cannot land last.
  Future<bool> _change(void Function() change) async {
    await ready;
    if (!loaded || _disposed) return false;
    change();
    _revision++;
    _notify();
    return retrySave();
  }

  Future<bool> retrySave() {
    if (!loaded || _disposed) return Future.value(false);
    final revision = _revision;
    final raw = jsonEncode({
      'version': 1,
      'saved': [..._saved.map((s) => s.toJson()), ..._unreadable],
      'draft': (_localSavingAllowed ? _draft : _previouslyStoredDraft)
          ?.toJson(),
      'localSavingAllowed': _localSavingAllowed,
      'unreadableDraft': _unreadableDraft,
      'soundOn': _soundOn,
      'cosmicMode': _cosmicMode,
    });
    final result = Completer<bool>();
    _writes = _writes.then((_) async {
      saving = true;
      _notify();
      try {
        // Native code acknowledges durable completion. Do not abandon an in-flight
        // write on a timer and start a competing write behind it.
        await _channel.invokeMethod<void>('write', raw);
        if (revision == _revision) saveError = null;
        result.complete(true);
      } catch (_) {
        saveError = 'Changes are kept in this session but could not be saved. Retry before closing the app.';
        result.complete(false);
      } finally {
        saving = false;
        _notify();
      }
    });
    return result.future;
  }

  void _put(SpinnerModel spinner) {
    final index = _saved.indexWhere((s) => s.id == spinner.id);
    final copy = spinner.copyWith(isTemplate: false);
    if (index < 0) {
      _saved.add(copy);
    } else {
      _saved[index] = copy;
    }
  }

  Future<bool> allowLocalSaving() => _change(() {
    _localSavingAllowed = true;
  });

  Future<bool> saveSpinner(SpinnerModel spinner) async {
    await ready;
    if (!_localSavingAllowed) return false;
    return _change(() {
      _put(spinner);
      if (_draft?.id == spinner.id) _draft = null;
    });
  }

  Future<bool> deleteSpinner(String id) =>
      _change(() => _saved.removeWhere((s) => s.id == id));
  Future<bool> restoreSpinner(SpinnerModel spinner) =>
      _change(() => _put(spinner));
  Future<bool> saveDraft(SpinnerModel spinner) async {
    await ready;
    if (!loaded || _disposed) return false;
    if (!_localSavingAllowed) {
      _draft = spinner.copyWith(isTemplate: false);
      _notify();
      return true;
    }
    return _change(() {
      _draft = spinner.copyWith(isTemplate: false);
    });
  }

  Future<bool> clearDraft() => _change(() {
    _draft = null;
    _previouslyStoredDraft = null;
  });
  Future<bool> toggleSound() => _change(() {
    _soundOn = !_soundOn;
  });
  Future<bool> toggleCosmicMode() => _change(() {
    _cosmicMode = !_cosmicMode;
  });
}
