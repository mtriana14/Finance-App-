import 'package:flutter/material.dart';

import 'feedback.dart';

/// Guards a screen's save action.
///
/// Every save in this app is "disable the button, await the database, pop".
/// Written by hand each time, that shape has two failure modes: a second tap
/// slips through before the flag is set, and — worse — a thrown exception
/// leaves the flag raised, so the button is dead until the merchant force-quits
/// the app, with nothing on screen explaining why. A merchant who has just
/// typed a fiado and cannot save it will write it on paper instead, which is
/// the one outcome this product cannot afford.
///
/// [submit] makes the correct shape the only shape: the flag is always
/// restored, the error is reported rather than swallowed, and the merchant is
/// told to try again.
mixin SubmitGuard<T extends StatefulWidget> on State<T> {
  bool _submitting = false;

  /// True while a save is in flight. Bind the button's `onPressed` to this.
  bool get submitting => _submitting;

  /// Runs [action] with the guard held. Returns true only if it completed, so
  /// callers can navigate on success and stay put on failure.
  Future<bool> submit(
    Future<void> Function() action, {
    String failureMessage = 'No se pudo guardar. Intenta de nuevo.',
  }) async {
    if (_submitting) return false;
    setState(() => _submitting = true);
    try {
      await action();
      return true;
    } catch (error, stack) {
      // Reported, not swallowed: this is where a crash reporter will look, and
      // in debug it fails the test that provoked it instead of passing quietly.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'libreta',
        context: ErrorDescription('saving from ${widget.runtimeType}'),
      ));
      if (mounted) showSnack(context, failureMessage, danger: true);
      return false;
    } finally {
      // The action may have popped this route; only touch state if it did not.
      if (mounted) setState(() => _submitting = false);
    }
  }
}
