//There is ONLY One Block Here/////////////////////////////////////////////
import 'package:flutter/material.dart';

/// A global dialog queue that ensures dialogs never overlap.
/// Each dialog request is added to a FIFO queue and processed
/// one at a time. If a dialog is already showing, new ones wait.
class DialogQueue {
  DialogQueue._internal();
  static final DialogQueue instance = DialogQueue._internal();

  final List<_DialogRequest> _queue = [];
  final Set<String> _pendingKeys = {};
  bool _isShowing = false;

  /// Add a dialog to the queue.
  void enqueue({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    VoidCallback? onShown,
    VoidCallback? onDismissed,
    String? dedupeKey,
  }) {
    if (dedupeKey != null && _pendingKeys.contains(dedupeKey)) {
      return;
    }

    if (dedupeKey != null) {
      _pendingKeys.add(dedupeKey);
    }

    _queue.add(
      _DialogRequest(
        context: context,
        builder: builder,
        onShown: onShown,
        onDismissed: onDismissed,
        dedupeKey: dedupeKey,
      ),
    );
    _processQueue();
  }

  void _invokeSafely(VoidCallback? callback) {
    if (callback == null) return;

    try {
      callback();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Cosmic Converter dialog queue',
        ),
      );
    }
  }

  /// Process queued dialogs one at a time.
  void _processQueue() async {
    if (_isShowing) return;

    _isShowing = true;

    try {
      while (_queue.isNotEmpty) {
        final request = _queue.removeAt(0);

        // If the context is no longer valid, skip this dialog.
        if (!request.context.mounted) {
          _pendingKeys.remove(request.dedupeKey);
          _invokeSafely(request.onDismissed);
          continue;
        }

        try {
          _invokeSafely(request.onShown);

          await showDialog(
            context: request.context,
            barrierDismissible: false,
            builder: request.builder,
          );
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'Cosmic Converter dialog queue',
            ),
          );
        } finally {
          _pendingKeys.remove(request.dedupeKey);
          _invokeSafely(request.onDismissed);
        }
      }
    } finally {
      _isShowing = false;
    }
  }
}

/// Internal dialog request object.
class _DialogRequest {
  final BuildContext context;
  final Widget Function(BuildContext) builder;
  final VoidCallback? onShown;
  final VoidCallback? onDismissed;
  final String? dedupeKey;

  _DialogRequest({
    required this.context,
    required this.builder,
    this.onShown,
    this.onDismissed,
    this.dedupeKey,
  });
}
