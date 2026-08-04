import 'package:flutter/material.dart';

/// Presentation shared by screens while their content is not yet available.
///
/// Keeping these states in one place gives loading, empty and error messages
/// the same hierarchy and guarantees a useful explanation and action.
enum ContentStateKind { loading, empty, error, success }

class ContentState extends StatelessWidget {
  final ContentStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;

  const ContentState({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.child,
  });

  const ContentState.loading({super.key, required this.title, required this.message})
      : kind = ContentStateKind.loading,
        actionLabel = null,
        onAction = null,
        child = null;

  const ContentState.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  })  : kind = ContentStateKind.empty,
        child = null;

  const ContentState.error({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'Réessayer',
    this.onAction,
  })  : kind = ContentStateKind.error,
        child = null;

  const ContentState.success({super.key, required this.child})
      : kind = ContentStateKind.success,
        title = '',
        message = '',
        actionLabel = null,
        onAction = null;

  @override
  Widget build(BuildContext context) {
    if (kind == ContentStateKind.success) return child!;
    final isLoading = kind == ContentStateKind.loading;
    final icon = kind == ContentStateKind.error
        ? Icons.error_outline
        : Icons.inbox_outlined;
    return Semantics(
      liveRegion: true,
      label: '$title. $message',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isLoading)
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    )),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      ),
    );
  }
}
