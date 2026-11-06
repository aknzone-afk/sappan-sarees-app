// Samppan store screenshots (6-Nov-2026): the real app on an Android emulator
// (on-photo prices repainted ×2 there — ML Kit runs on Android), signed up
// like a customer, photographing the main screens. No order is placed.
// Run by the "Store screenshots" workflow:
//   flutter drive --driver=test_driver/shots.dart --target=integration_test/store_shots_test.dart --profile
import 'package:catalog_app/app.dart' show appRouter;
import 'package:catalog_app/main.dart' as app;
import 'package:catalog_app/models/photo.dart';
import 'package:catalog_app/providers/providers.dart';
import 'package:catalog_app/services/account_service.dart';
import 'package:catalog_app/services/model_pics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (t) async {
    Future<void> wait(double s) async {
      final end = DateTime.now().add(Duration(milliseconds: (s * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    Future<bool> waitFor(Finder f, {double secs = 30}) async {
      final end = DateTime.now().add(Duration(milliseconds: (secs * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 200));
        if (f.evaluate().isNotEmpty) return true;
      }
      return false;
    }

    Future<void> shot(String name, {double settle = 6}) async {
      await wait(settle);
      await binding.takeScreenshot(name);
    }

    // a signed-up customer (stored the way the sign-up screen stores it — no
    // fake sign-up is sent to the shop)
    final prefs = await SharedPreferences.getInstance();
    await AccountService.approve(prefs, {
      'mobile': '9876543210',
      'india': true,
      'kind': 'retail',
      'cust': {
        'name': 'Ananya Sharma', 'billName': 'Ananya Sharma',
        'address': '12 MG Road, Indiranagar, Bengaluru', 'pincode': '560038',
        'city': 'Bengaluru', 'state': 'Karnataka', 'country': 'India',
      },
    });
    app.main();
    await wait(3);
    await binding.convertFlutterSurfaceToImage();

    // first launch: live catalogue, covers, then the on-photo prices
    await waitFor(find.text('NEW IN'), secs: 120);
    await wait(60);

    appRouter.go('/');
    await shot('01_home', settle: 10);

    final scroll = find.byType(Scrollable).first;
    await t.drag(scroll, const Offset(0, -900));
    await shot('02_collections', settle: 8);

    appRouter.push('/new');
    await shot('03_new_in', settle: 25);

    // a design that has a modelling photo
    final container = ProviderScope.containerOf(t.element(find.byType(Navigator).first));
    Map<String, List<String>> models = const {};
    try {
      models = await container.read(modelPicsProvider.future).timeout(const Duration(seconds: 20));
    } catch (_) {}
    final photos = [...container.read(photosProvider)]..sort(Photo.compareNewestFirst);
    final withModel = photos.where((p) => modelPicsOf(models, p.designNumber).isNotEmpty).toList();
    final pick = withModel.isNotEmpty ? withModel.first : photos.first;

    appRouter.push('/pick/${Uri.encodeComponent(pick.id)}');
    await wait(4);
    if (await waitFor(find.text('OK, start'), secs: 8)) {
      await t.tap(find.text('OK, start'), warnIfMissed: false);
      await wait(2);
    }
    final area = find.byWidgetPredicate((w) => w is GestureDetector && w.onTapUp != null);
    if (await waitFor(area, secs: 10)) {
      await t.tapAt(t.getCenter(area.first));
    }
    await shot('04_choose_colour', settle: 4);

    if (await waitFor(find.text('VIEW ON MODEL'), secs: 5)) {
      await t.tap(find.text('VIEW ON MODEL'), warnIfMissed: false);
      await shot('05_on_model', settle: 1.4);
      await wait(3);
    }
    if (await waitFor(find.text('DONE'), secs: 5)) {
      await t.tap(find.text('DONE').first, warnIfMissed: false);
      await wait(2);
    }

    appRouter.go('/favorites');
    await shot('06_bag', settle: 8);

    appRouter.push('/order');
    await shot('07_order', settle: 6);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
