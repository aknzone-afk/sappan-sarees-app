// App Review demo (Apple Guideline 2.1, 31-Oct-2026): walks the typical
// customer flow on the iOS simulator while the CI job screen-records it:
// launch → sign up → browse → open a saree → choose colour → bag →
// place order → My Orders → delete account.
// Run: flutter test integration_test/review_flow_test.dart -d <simulator>
import 'package:catalog_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Review flow', (tester) async {
    Future<void> idle(double s) async {
      final end = DateTime.now().add(Duration(milliseconds: (s * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<bool> waitFor(Finder f, {double secs = 30}) async {
      final end = DateTime.now().add(Duration(milliseconds: (secs * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (f.evaluate().isNotEmpty) return true;
      }
      debugPrint('REVIEW-FLOW: not found: $f');
      return false;
    }

    Future<void> tapIt(Finder f, {double after = 2}) async {
      if (!await waitFor(f)) return;
      await tester.ensureVisible(f.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(f.first, warnIfMissed: false);
      await idle(after);
    }

    Future<void> typeInto(String label, String text) async {
      final f = find.widgetWithText(TextFormField, label);
      if (!await waitFor(f)) return;
      await tester.ensureVisible(f);
      await tester.tap(f, warnIfMissed: false);
      await idle(0.4);
      await tester.enterText(f, text);
      await idle(1.0);
    }

    app.main();
    await idle(4); // launch + splash

    // 1. Sign-up (no password, no approval).
    await waitFor(find.text('START SHOPPING'), secs: 40);
    await idle(2);
    await typeInto('Your Name *', 'App Review');
    await typeInto('Mobile No. *', '9876543210');
    await typeInto('Full Address *', '12 Demo Street, Connaught Place, New Delhi');
    await typeInto('Pincode *', '110001');
    FocusManager.instance.primaryFocus?.unfocus();
    await idle(2.5);
    await tapIt(find.text('START SHOPPING'), after: 4);

    // 2. Browse the storefront (catalogue loads from the cloud).
    await waitFor(find.text('NEW IN'), secs: 60);
    await idle(6);
    final scroll = find.byType(Scrollable).first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(scroll, const Offset(0, -350));
      await idle(1.6);
    }
    for (var i = 0; i < 4; i++) {
      await tester.drag(scroll, const Offset(0, 350));
      await idle(0.8);
    }

    // Move between screens the way the bottom bar does (some screens have no
    // bottom bar, so go through the app's own router).
    Future<void> goTo(String route, {double after = 4}) async {
      final ctx = tester.element(find.byType(Scaffold).last);
      GoRouter.of(ctx).go(route);
      await idle(after);
    }

    // 3. New In -> a saree -> CHOOSE COLOUR -> close the tip -> tap the saree -> DONE.
    await tapIt(find.text('NEW IN').last, after: 8);
    await tapIt(find.textContaining('CHOOSE COLOUR'), after: 4);
    if (await waitFor(find.text('OK, start'), secs: 6)) {
      await idle(2.5); // let the viewer read the tip
      await tapIt(find.text('OK, start'), after: 2);
    }
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width / 2, size.height * 0.5));
    await idle(3);
    await tapIt(find.text('DONE'), after: 3);

    // 4. Shopping bag -> PLACE ORDER -> details -> confirm.
    await goTo('/');
    await tapIt(find.text('BAG').last, after: 5);
    await tapIt(find.textContaining('PLACE ORDER'), after: 6);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await idle(2);
    await tapIt(find.textContaining('PLACE ORDER ·'), after: 3);
    await tapIt(find.text('YES, PLACE ORDER'), after: 12);
    await idle(4);

    // 5. My Orders -> menu -> Delete my account.
    await goTo('/');
    await tapIt(find.text('ORDERS').last, after: 6);
    await tapIt(find.byType(PopupMenuButton<String>), after: 2);
    await tapIt(find.text('Delete my account'), after: 3);
    await tapIt(find.text('Delete'), after: 8);
    await idle(4);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
