import Flutter
import GoogleMaps
import UIKit

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
          result(AppDelegate.mapsApiKey)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// The configured key, or nil when Secrets.xcconfig doesn't set one.
  static var mapsApiKey: String? {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
    else { return nil }
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
  }
}
