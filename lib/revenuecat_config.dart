/// RevenueCat keys and product identifiers.
///
/// The PUBLIC SDK keys are safe to ship in the binary — they can only read
/// offerings and start purchases the store itself authorises. The SECRET key
/// never leaves the server (Railway: RC_SECRET_KEY).
///
/// Empty key = the whole paid layer stays dormant: no purchase calls, and
/// every account behaves exactly as it did before payments existed. Same
/// contract as [FirebaseCfg].
///
/// On Android, RevenueCat owns the Google Play Billing Library version too —
/// we never depend on `com.android.billingclient` ourselves, so the only way
/// to move it is to bump `purchases_flutter`. Which version that lands us on,
/// and which one Play actually requires, is in docs/PLAY_COMPLIANCE.md.
///
/// ---------------------------------------------------------------------
/// SETUP CHECKLIST — the names below must match EXACTLY in three places
/// ---------------------------------------------------------------------
/// 1. App Store Connect → Subscriptions → create a Subscription Group
///    ("Rivler Pro"), then two auto-renewable subscriptions inside it:
///       rivler_pro_weekly    £4.99 / 1 week
///       rivler_pro_monthly   £14.99 / 1 month
///    Both need a localised display name, description, and a review
///    screenshot, or the product stays "Missing Metadata" and never
///    appears in the app.
///
/// 2. Google Play Console → Monetise → Subscriptions: the SAME two product
///    ids, same prices, same billing periods.
///
/// 3. RevenueCat dashboard:
///    • Products: import both ids from each store
///    • Entitlement: create ONE, id `pro`, and attach both products to it
///    • Offering: create one, id `default`, with two packages —
///        $rc_weekly  → rivler_pro_weekly
///        $rc_monthly → rivler_pro_monthly
///      (the paywall lists whatever packages `default` contains, in order,
///       and reads price + period straight from the store, so changing a
///       price never needs a new build)
///    • API keys → paste the Apple and Google PUBLIC keys below, and set
///      RC_SECRET_KEY + RC_ENTITLEMENT=pro on Railway.
class RcCfg {
  RcCfg._();

  /// App Store public SDK key from RevenueCat → Project → API keys.
  static const String appleKey = 'appl_CsDgWBlxPhQjiFdlAOBOAYteYSJ';

  /// Google Play public SDK key from the same screen. Android reads this
  /// one; iOS reads [appleKey].
  static const String googleKey = '';

  /// The entitlement identifier configured in RevenueCat. Must match the
  /// server's RC_ENTITLEMENT.
  static const String entitlement = 'pro';

  /// The offering whose packages the paywall lists. RevenueCat serves the
  /// one marked current when this is left as 'default'.
  static const String offering = 'default';

  /// Store product ids — documentation for the setup above. Nothing reads
  /// these at runtime (the SDK works in packages, not raw ids), but a
  /// mismatch between here and the stores is the single most common reason
  /// a paywall renders empty, so they live in the code as the source of truth.
  static const String weeklyProductId = 'rivler_pro_weekly';
  static const String monthlyProductId = 'rivler_pro_monthly';

  /// DISPLAY-ONLY fallback prices, used by the paywall for exactly one
  /// purpose: so the layout can be reviewed on a device before the SDK keys
  /// land. The moment [configured] is true these are never read again — the
  /// paywall shows what the store says, in the viewer's own currency, and a
  /// price change never needs a new build.
  ///
  /// Keep them in step with the products created in App Store Connect and Play
  /// Console, or a pre-keys build will advertise a price that isn't real.
  static const String weeklyPriceHint = '£4.99';
  static const String monthlyPriceHint = '£14.99';
  static const double weeklyPriceHintValue = 4.99;
  static const double monthlyPriceHintValue = 14.99;

  static bool get configured => appleKey.isNotEmpty || googleKey.isNotEmpty;
}
