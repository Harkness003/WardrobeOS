import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/widgets/app_feedback.dart';

void main() {
  testWidgets('brief feedback replaces the previous message and disappears', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (value) {
        context = value;
        return const SizedBox();
      },
    ))));

    AppFeedback.show(context, 'Premier');
    await tester.pump();
    AppFeedback.show(context, 'Terminé');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Premier'), findsNothing);
    expect(find.text('Terminé'), findsOneWidget);
    await tester.pump(AppFeedback.briefDuration);
    await tester.pumpAndSettle();
    expect(find.text('Terminé'), findsNothing);
  });

  testWidgets('feedback with an action leaves enough time to undo', (tester) async {
    late BuildContext context;
    var undone = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (value) {
        context = value;
        return const SizedBox();
      },
    ))));

    AppFeedback.show(context, 'Supprimé', action: SnackBarAction(
      label: 'Annuler', onPressed: () => undone = true,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    expect(undone, isTrue);
  });
}
