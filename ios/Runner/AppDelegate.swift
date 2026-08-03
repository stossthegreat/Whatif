import Flutter
import UIKit
import Security

/// Device identity that outlives a reinstall.
///
/// UserDefaults (and therefore SharedPreferences) is wiped when the app is
/// deleted, which is exactly why bans used to be a suggestion: delete,
/// reinstall, brand-new identity, straight back in. Keychain items survive app
/// deletion, so a UUID stored here is a stable anchor for sanctions.
///
/// Deliberately `ThisDeviceOnly`: we want per-HARDWARE identity, not something
/// that syncs to iCloud and follows the user onto a clean phone.
private enum DeviceKeychain {
  private static let service = "com.rivlr.app.device"
  private static let account = "deviceId"

  static func load() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let value = String(data: data, encoding: .utf8),
          !value.isEmpty
    else { return nil }
    return value
  }

  @discardableResult
  static func save(_ value: String) -> Bool {
    guard let data = value.data(using: .utf8) else { return false }
    // clear any stale entry first so add can't fail with duplicate-item
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(base as CFDictionary)
    var attrs = base
    attrs[kSecValueData as String] = data
    attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
  }

  /// Existing id, or a freshly minted and persisted one. Returns nil only if
  /// the Keychain itself refuses — the Dart side treats that as "no device
  /// binding available" and carries on.
  static func ensure() -> String? {
    if let existing = load() { return existing }
    let fresh = UUID().uuidString
    return save(fresh) ? fresh : nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "rivlr/native",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "deviceId":
          result(DeviceKeychain.ensure())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
