import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Hands reels saved by the "Share to Hoopla" extension to the Flutter app.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HooplaSharedReels") {
      let channel = FlutterMethodChannel(name: "hoopla/share", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "takeSharedReels" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let defaults = UserDefaults(suiteName: "group.com.northbitapps.hoopla")
        let items = defaults?.array(forKey: "pendingReels") ?? []
        defaults?.removeObject(forKey: "pendingReels")
        result(items)
      }
    }
  }
}
