import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps key from ios/Flutter/Secrets.xcconfig via Info.plist.
    if let key = AppDelegate.mapsApiKey {
      GMSServices.provideAPIKey(key)
    }
    // S19 / S20: lets flutter_local_notifications (and firebase_messaging)
    // handle notifications shown while the app is open and taps on them.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Lets Dart skip the map when no key is configured: creating a map view
    // without one makes the Google Maps SDK throw and crash the app.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KidpoolMaps") {
      let channel = FlutterMethodChannel(
        name: "kidpool/maps", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "isConfigured" {
          result(AppDelegate.mapsApiKey != nil)
        } else if call.method == "apiKey" {
          // Places search may use its own key (Secrets.xcconfig
          // GOOGLE_PLACES_API_KEY); otherwise the map key.
          result(AppDelegate.placesApiKey ?? AppDelegate.mapsApiKey)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// The map key, or nil when Secrets.xcconfig doesn't set one.
  static var mapsApiKey: String? { infoKey("GMSApiKey") }

  /// The Places search key, or nil to use [mapsApiKey].
  static var placesApiKey: String? { infoKey("KidpoolPlacesApiKey") }

  private static func infoKey(_ name: String) -> String? {
    guard let key = Bundle.main.object(forInfoDictionaryKey: name) as? String
    else { return nil }
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
  }
}
