/// RevenueCat keys. The PUBLIC Apple SDK key is safe to ship in the binary —
/// it can only read offerings and start purchases Apple itself authorises.
/// The secret key never leaves the server.
///
/// Empty key = the whole paid layer stays dormant: no paywall entry points,
/// no purchase calls, and every account behaves exactly as it did before
/// payments existed. Same contract as [FirebaseCfg].
class RcCfg {
  RcCfg._();

  /// App Store public SDK key from RevenueCat → Project → API keys.
  static const String appleKey = '';

  /// The entitlement identifier configured in RevenueCat. Must match the
  /// server's RC_ENTITLEMENT (default 'plus').
  static const String entitlement = 'plus';

  static bool get configured => appleKey.isNotEmpty;
}
