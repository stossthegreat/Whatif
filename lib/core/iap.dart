import 'dart:async';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../net/api_client.dart';
import '../net/network_client.dart';
import '../revenuecat_config.dart';
import '../state/session.dart';
import 'analytics.dart';

/// Rivlr+ purchases. RevenueCat talks to the App Store; our server decides
/// who is entitled. This class never grants anything itself — every path
/// ends in [Api.syncPlus], which makes the server ask RevenueCat and reply
/// over the socket. A hacked client can call anything here and still not be
/// Plus.
///
/// Entirely dormant when [RcCfg.configured] is false, so the app runs
/// exactly as it did before payments until real keys land.
class Plus {
  Plus._();
  static final Plus instance = Plus._();

  bool _ready = false;
  Offering? _offering;

  /// The packages to show, cheapest period first. Empty until [start] runs.
  List<Package> get packages => _offering?.availablePackages ?? const [];

  /// Set up the SDK and identify this device as OUR user. The RevenueCat
  /// app_user_id MUST equal our uid — it's the key the server looks the
  /// subscription up by, and the id RevenueCat puts in every webhook.
  Future<void> start() async {
    if (!RcCfg.configured || _ready) return;
    try {
      await Purchases.setLogLevel(LogLevel.error);
      await Purchases.configure(
        PurchasesConfiguration(RcCfg.appleKey)
          ..appUserID = AppSession.instance.myUid,
      );
      _ready = true;
      await _loadOfferings();
      // a live subscription bought on another device shows up here
      unawaited(Api.syncPlus());
    } catch (_) {/* store unreachable — the paywall just won't offer prices */}
  }

  /// Apple sign-in can adopt a different (canonical) uid. RevenueCat has to
  /// follow, or the purchase ends up filed under the abandoned account.
  Future<void> relogin(String uid) async {
    if (!_ready) return;
    try {
      await Purchases.logIn(uid);
      await _loadOfferings();
      unawaited(Api.syncPlus());
    } catch (_) {/* ignore */}
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      _offering = offerings.current;
    } catch (_) {
      _offering = null;
    }
  }

  /// Refresh the price list — the paywall calls this on open so a cold start
  /// that missed the network still shows real prices.
  Future<void> refresh() async {
    if (!_ready) {
      await start();
      return;
    }
    await _loadOfferings();
  }

  /// Buy. Returns true only once OUR SERVER agrees the subscription is live.
  /// [cancelled] tells the paywall to stay quiet rather than show an error.
  Future<PurchaseResult> buy(Package p) async {
    if (!_ready) return PurchaseResult.unavailable;
    try {
      Track.event('plus_purchase_start', {'package': p.identifier});
      await Purchases.purchasePackage(p);
      final live = await _confirmWithServer();
      Track.event(live ? 'plus_purchase_done' : 'plus_purchase_unconfirmed');
      return live ? PurchaseResult.success : PurchaseResult.pending;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      return PurchaseResult.failed;
    } catch (_) {
      return PurchaseResult.failed;
    }
  }

  /// Apple requires this on every paywall — someone who reinstalls must be
  /// able to get back what they already paid for.
  Future<PurchaseResult> restore() async {
    if (!_ready) return PurchaseResult.unavailable;
    try {
      await Purchases.restorePurchases();
      final live = await _confirmWithServer();
      Track.event('plus_restore', {'found': live ? 1 : 0});
      return live ? PurchaseResult.success : PurchaseResult.nothingToRestore;
    } catch (_) {
      return PurchaseResult.failed;
    }
  }

  /// The only thing that actually turns Plus on: the server re-checks with
  /// RevenueCat and pushes the entitlement back down the socket. We poll
  /// briefly because App Store receipts can take a moment to propagate.
  Future<bool> _confirmWithServer() async {
    for (var i = 0; i < 3; i++) {
      if (await Api.syncPlus()) return true;
      if (AppSession.instance.plus) return true; // the socket beat us to it
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    // last resort: a reconnect re-reads the entitlement from the database
    NetworkClient.instance.hello();
    return AppSession.instance.plus;
  }
}

enum PurchaseResult {
  success,
  cancelled,
  failed,
  /// Paid, but the entitlement hasn't reached us yet — it will.
  pending,
  nothingToRestore,
  /// Store or keys unavailable — never shown as an error the user caused.
  unavailable,
}
