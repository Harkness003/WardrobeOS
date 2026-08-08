import 'package:flutter/material.dart';

/// Shared, deliberately simple convention for transient user feedback.
abstract final class AppFeedback {
  static const briefDuration = Duration(milliseconds: 2500);
  static const actionDuration = Duration(seconds: 6);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: action == null ? briefDuration : actionDuration,
        action: action,
      ),
    );
  }
}
